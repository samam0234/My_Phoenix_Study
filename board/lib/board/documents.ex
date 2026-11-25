defmodule Board.Documents do
  @moduledoc """
  문서 요약·질문. DocuForge의 흐름(올리기 → 요약 → 발췌 근거 답변)을
  Phoenix 한 앱 안의 텍스트 예제로 다시 만든 것이다.
  """

  import Ecto.Query
  alias Board.Accounts.User
  alias Board.AI.{Client, Prompt, Search}
  alias Board.Documents.{Document, Question}
  alias Board.Jobs.SummaryWorker
  alias Board.Repo

  def list_documents(%User{} = user) do
    Repo.all(from d in Document, where: d.user_id == ^user.id, order_by: [desc: d.id])
  end

  def get_document(%User{} = user, id) when is_integer(id) do
    Repo.get_by(Document, id: id, user_id: user.id)
  end

  def list_questions(%Document{} = document) do
    Repo.all(from q in Question, where: q.document_id == ^document.id, order_by: [asc: q.id])
  end

  def create_document(%User{} = user, attrs, opts \\ []) do
    attrs =
      attrs
      |> stringify()
      |> Map.put("user_id", user.id)
      |> Map.put_new("content_type", "text/plain")
      |> Map.put_new("filename", "memo.txt")

    attrs =
      if is_binary(attrs["original_text"]) do
        Map.put(attrs, "byte_size", byte_size(attrs["original_text"]))
      else
        attrs
      end

    %Document{}
    |> Document.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, document} ->
        if Keyword.get(opts, :async, false) do
          SummaryWorker.enqueue(document.id)
          {:ok, document}
        else
          SummaryWorker.summarize_now(document.id)
        end

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def create_from_upload(%User{} = user, %Plug.Upload{} = upload) do
    extension = upload.filename |> Path.extname() |> String.downcase()

    cond do
      extension not in [".txt", ".md", ".markdown"] ->
        {:error, :bad_request}

      true ->
        case File.stat(upload.path) do
          {:ok, %{size: size}} when size > 10_000_000 ->
            {:error, :payload_too_large}

          {:ok, _stat} ->
            read_upload(user, upload)

          {:error, _reason} ->
            {:error, :bad_request}
        end
    end
  end

  defp read_upload(user, upload) do
    case File.read(upload.path) do
      {:ok, text} ->
        if String.valid?(text) do
          create_document(user, %{
            "filename" => upload.filename,
            "content_type" => upload.content_type || "text/plain",
            "original_text" => text
          })
        else
          {:error, :bad_request}
        end

      {:error, _reason} ->
        {:error, :bad_request}
    end
  end

  def save_summary(%Document{} = document, summary) when is_binary(summary) do
    document
    |> Ecto.Changeset.change(%{summary: summary})
    |> Repo.update()
  end

  def ask(%Document{} = document, question) when is_binary(question) do
    question = String.trim(question)

    if question == "" do
      {:error, :bad_request}
    else
      excerpts = Search.top_excerpts(document.original_text, question, 3)

      answer =
        if excerpts == [] do
          "문서에서 찾을 수 없습니다."
        else
          case Client.complete(Prompt.ask(question, excerpts), fn ->
                 first = excerpts |> List.first() |> Map.get(:text, "")
                 "#{String.slice(first, 0, 80)} (발췌 1)"
               end) do
            {:ok, text} -> text
            {:error, _reason} -> "AI 응답을 가져오지 못했습니다."
          end
        end

      %Question{}
      |> Question.changeset(%{
        question: question,
        answer: answer,
        sources:
          Enum.map(excerpts, fn excerpt ->
            %{
              "chunk_index" => excerpt.chunk_index,
              "text" => excerpt.text,
              "score" => excerpt.score
            }
          end),
        document_id: document.id
      })
      |> Repo.insert()
    end
  end

  defp stringify(attrs) when is_map(attrs) do
    Map.new(attrs, fn {key, value} -> {to_string(key), value} end)
  end
end
