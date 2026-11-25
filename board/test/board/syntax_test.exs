defmodule Board.SyntaxTest do
  use ExUnit.Case, async: true

  test "greet and classify" do
    assert Board.Syntax.greet(" Mina ") == "안녕하세요, Mina"
    assert Board.Syntax.greet("  ") == "안녕하세요, Phoenix"
    assert Board.Syntax.pipeline_demo("Hello Phoenix") == "hello-phoenix"
    assert Board.Syntax.classify(2) == :positive
    assert Board.Syntax.classify(0) == :zero
    assert Board.Syntax.classify(-1) == :negative
  end
end
