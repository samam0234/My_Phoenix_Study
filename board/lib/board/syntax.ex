defmodule Board.Syntax do
  @moduledoc """
  study1에서 보는 Elixir 기본 문법.
  패턴 매칭, 가드, 파이프만 담는다.
  """

  def greet(name) when is_binary(name) do
    case String.trim(name) do
      "" -> "안녕하세요, Phoenix"
      trimmed -> "안녕하세요, #{trimmed}"
    end
  end

  def greet(_other), do: "안녕하세요, Phoenix"

  def pipeline_demo(name) when is_binary(name) do
    name
    |> String.trim()
    |> String.downcase()
    |> String.replace(~r/\s+/u, "-")
  end

  def pipeline_demo(_other), do: "phoenix"

  def classify(n) when is_integer(n) and n > 0, do: :positive
  def classify(0), do: :zero
  def classify(n) when is_integer(n) and n < 0, do: :negative
  def classify(_other), do: :other
end
