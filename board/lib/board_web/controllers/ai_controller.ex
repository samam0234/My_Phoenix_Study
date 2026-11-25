defmodule BoardWeb.AiController do
  use BoardWeb, :controller
  action_fallback BoardWeb.FallbackController

  def stream(conn, %{"text" => text}) when is_binary(text) and text != "" do
    case Board.AI.Client.stream_tokens(text) do
      {:ok, tokens} -> send_sse(conn, tokens)
      {:error, _reason} -> {:error, :ai_unavailable}
    end
  end

  def stream(_conn, _params), do: {:error, :bad_request}

  defp send_sse(conn, tokens) do
    conn =
      conn
      |> put_resp_content_type("text/event-stream")
      |> put_resp_header("cache-control", "no-cache")
      |> send_chunked(200)

    conn =
      Enum.reduce(tokens, conn, fn token, conn ->
        payload = "data: " <> Jason.encode!(%{token: token}) <> "\n\n"

        case chunk(conn, payload) do
          {:ok, conn} -> conn
          {:error, _reason} -> conn
        end
      end)

    case chunk(conn, "data: [DONE]\n\n") do
      {:ok, conn} -> conn
      {:error, _reason} -> conn
    end
  end
end
