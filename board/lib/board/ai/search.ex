defmodule Board.AI.Search do
  @moduledoc """
  임베딩 없이 단어와 글자 2개 묶음이 겹치는 정도로 발췌를 고른다.
  """

  def top_excerpts(text, question, limit \\ 3) when is_binary(text) and is_binary(question) do
    question_terms = terms(question)

    text
    |> chunk()
    |> Enum.with_index()
    |> Enum.map(fn {part, index} ->
      overlap = MapSet.intersection(terms(part), question_terms) |> MapSet.size()

      score =
        if MapSet.size(question_terms) == 0, do: 0.0, else: overlap / MapSet.size(question_terms)

      %{chunk_index: index, text: part, score: Float.round(score, 4)}
    end)
    |> Enum.filter(&(&1.score > 0))
    |> Enum.sort_by(& &1.score, :desc)
    |> Enum.take(limit)
  end

  def chunk(text) when is_binary(text) do
    parts =
      text
      |> String.split(~r/\n\s*\n/u, trim: true)
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    parts = if parts == [], do: [String.trim(text)], else: parts
    parts |> Enum.flat_map(&slice_chunk/1) |> Enum.reject(&(&1 == ""))
  end

  defp slice_chunk(text) do
    if String.length(text) <= 400 do
      [text]
    else
      text |> String.graphemes() |> Enum.chunk_every(400) |> Enum.map(&Enum.join/1)
    end
  end

  defp terms(text) do
    lowered = String.downcase(text)
    words = String.split(lowered, ~r/[^\p{L}\p{N}]+/u, trim: true)

    bigrams =
      lowered
      |> String.replace(~r/\s+/u, "")
      |> String.graphemes()
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.map(&Enum.join/1)

    MapSet.new(words ++ bigrams)
  end
end
