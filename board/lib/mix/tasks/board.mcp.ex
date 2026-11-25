defmodule Mix.Tasks.Board.Mcp do
  use Mix.Task

  @shortdoc "한 줄 JSON MCP 서버를 표준 입력으로 돌린다"

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")

    IO.stream(:stdio, :line)
    |> Enum.each(fn line ->
      case Jason.decode(String.trim(line)) do
        {:ok, message} ->
          case Board.MCP.Server.handle_message(message) do
            nil -> :ok
            response -> IO.puts(Jason.encode!(response))
          end

        {:error, _reason} ->
          :ok
      end
    end)
  end
end
