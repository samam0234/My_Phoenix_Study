defmodule Board.MCPTest do
  use ExUnit.Case, async: true

  test "lists tools and summarizes without a network" do
    listed =
      Board.MCP.Server.handle_message(%{"jsonrpc" => "2.0", "id" => 1, "method" => "tools/list"})

    names = Enum.map(listed.result.tools, & &1.name)
    assert "summarize_document" in names
    assert "ask_document" in names

    summary =
      Board.MCP.Server.handle_message(%{
        "jsonrpc" => "2.0",
        "id" => 2,
        "method" => "tools/call",
        "params" => %{"name" => "summarize_document", "arguments" => %{"text" => "서버가 상태를 가진다"}}
      })

    assert hd(summary.result.content).text =~ "요약:"

    decoded = Board.AI.Client.decode_ollama_line(~s({"response":"안녕","done":false}))
    assert decoded == {:ok, "안녕", false}
  end
end
