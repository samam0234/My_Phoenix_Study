defmodule Board.MCP.Server do
  @moduledoc """
  표준 입력으로 한 줄 JSON을 받아 도구 목록과 문서 요약·질문을 돌려준다.
  """

  alias Board.AI.{Client, Search}

  def handle_message(%{"id" => id} = message) do
    case dispatch(message) do
      {:ok, result} -> %{jsonrpc: "2.0", id: id, result: result}
      {:error, code, message} -> %{jsonrpc: "2.0", id: id, error: %{code: code, message: message}}
    end
  end

  def handle_message(_message), do: nil

  defp dispatch(%{"method" => "initialize"}) do
    {:ok,
     %{
       protocolVersion: "2024-11-05",
       capabilities: %{tools: %{}},
       serverInfo: %{name: "board-phoenix", version: "0.1.0"}
     }}
  end

  defp dispatch(%{"method" => "tools/list"}) do
    {:ok, %{tools: [summarize_tool(), ask_tool()]}}
  end

  defp dispatch(%{
         "method" => "tools/call",
         "params" => %{"name" => "summarize_document"} = params
       }) do
    text = params |> Map.get("arguments", %{}) |> Map.get("text", "")

    if text == "" do
      {:error, -32602, "text가 필요합니다."}
    else
      case Client.summarize(text) do
        {:ok, summary} -> {:ok, text_content(summary)}
        {:error, _reason} -> {:error, -32000, "AI 응답을 가져오지 못했습니다."}
      end
    end
  end

  defp dispatch(%{"method" => "tools/call", "params" => %{"name" => "ask_document"} = params}) do
    args = Map.get(params, "arguments", %{})
    text = Map.get(args, "text", "")
    question = Map.get(args, "question", "")

    cond do
      text == "" or question == "" ->
        {:error, -32602, "text와 question이 필요합니다."}

      true ->
        excerpts = Search.top_excerpts(text, question, 3)

        answer =
          if excerpts == [] do
            "문서에서 찾을 수 없습니다."
          else
            first = hd(excerpts)
            "#{String.slice(first.text, 0, 80)} (발췌 #{first.chunk_index + 1})"
          end

        {:ok, text_content(answer)}
    end
  end

  defp dispatch(%{"method" => "tools/call"}) do
    {:error, -32602, "없는 도구입니다."}
  end

  defp dispatch(_message), do: {:error, -32601, "없는 메서드입니다."}

  defp summarize_tool do
    %{
      name: "summarize_document",
      description: "문서 본문을 짧게 요약한다.",
      inputSchema: %{
        type: "object",
        properties: %{text: %{type: "string"}},
        required: ["text"]
      }
    }
  end

  defp ask_tool do
    %{
      name: "ask_document",
      description: "문서 발췌만 근거로 질문에 답한다.",
      inputSchema: %{
        type: "object",
        properties: %{text: %{type: "string"}, question: %{type: "string"}},
        required: ["text", "question"]
      }
    }
  end

  defp text_content(text) do
    %{content: [%{type: "text", text: text}], isError: false}
  end
end
