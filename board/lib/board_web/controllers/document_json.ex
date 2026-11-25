defmodule BoardWeb.DocumentJSON do
  def index(%{documents: documents}) do
    %{data: Enum.map(documents, &data/1), meta: %{total: length(documents)}}
  end

  def show(%{document: document}) do
    %{data: data(document)}
  end

  def question(%{question: question}) do
    %{
      data: %{
        id: question.id,
        question: question.question,
        answer: question.answer,
        sources: question.sources
      }
    }
  end

  defp data(document) do
    %{
      id: document.id,
      filename: document.filename,
      summary: document.summary,
      byteSize: document.byte_size,
      createdAt: document.inserted_at |> DateTime.truncate(:second) |> DateTime.to_iso8601()
    }
  end
end
