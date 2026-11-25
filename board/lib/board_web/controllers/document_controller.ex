defmodule BoardWeb.DocumentController do
  use BoardWeb, :controller

  alias Board.Documents
  alias BoardWeb.Params
  action_fallback BoardWeb.FallbackController

  plug :require_browser_user when action in [:create]

  def index(conn, _params) do
    documents = Documents.list_documents(conn.assigns.current_user)
    render(conn, :index, documents: documents)
  end

  def show(conn, %{"id" => id}) do
    with {:ok, id} <- Params.id(id),
         %{} = document <- Documents.get_document(conn.assigns.current_user, id) do
      render(conn, :show, document: document)
    else
      :error -> {:error, :bad_request}
      nil -> {:error, :not_found}
    end
  end

  def create(conn, %{"file" => %Plug.Upload{} = upload}) do
    finish(conn, Documents.create_from_upload(conn.assigns.current_user, upload))
  end

  def create(conn, %{"text" => text} = params) do
    attrs = %{
      "filename" => params["filename"] || "memo.txt",
      "original_text" => text,
      "content_type" => "text/plain"
    }

    finish(
      conn,
      Documents.create_document(conn.assigns.current_user, attrs, async: params["async"] == "1")
    )
  end

  def create(_conn, _params), do: {:error, :bad_request}

  def ask(conn, %{"id" => id, "question" => question}) do
    with {:ok, id} <- Params.id(id),
         %{} = document <- Documents.get_document(conn.assigns.current_user, id),
         {:ok, saved} <- Documents.ask(document, question) do
      render(conn, :question, question: saved)
    else
      :error -> {:error, :bad_request}
      nil -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  def ask(_conn, _params), do: {:error, :bad_request}

  defp finish(conn, {:ok, document}) do
    if get_format(conn) == "json" do
      conn |> put_status(:created) |> render(:show, document: document)
    else
      conn
      |> put_flash(:info, "문서를 올렸습니다.")
      |> redirect(to: ~p"/documents/#{document.id}")
    end
  end

  defp finish(conn, {:error, reason}) do
    if get_format(conn) == "json" do
      {:error, reason}
    else
      conn
      |> put_flash(:error, "문서를 저장하지 못했습니다. txt 또는 md 파일인지 확인하세요.")
      |> redirect(to: ~p"/documents")
    end
  end

  defp require_browser_user(conn, _opts) do
    if get_format(conn) == "html" and is_nil(conn.assigns[:current_user]) do
      conn
      |> put_flash(:error, "로그인이 필요합니다.")
      |> redirect(to: ~p"/login")
      |> halt()
    else
      conn
    end
  end
end
