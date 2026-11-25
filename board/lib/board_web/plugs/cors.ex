defmodule BoardWeb.Plugs.CORS do
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    origin = Application.get_env(:board, :cors_origin, "http://localhost:5173")

    conn =
      conn
      |> put_resp_header("access-control-allow-origin", origin)
      |> put_resp_header("access-control-allow-credentials", "true")
      |> put_resp_header(
        "access-control-allow-headers",
        "authorization, content-type, x-request-id"
      )
      |> put_resp_header("access-control-allow-methods", "GET, POST, PATCH, DELETE, OPTIONS")
      |> put_resp_header("vary", "origin")

    if conn.method == "OPTIONS" do
      conn |> send_resp(204, "") |> halt()
    else
      conn
    end
  end
end
