defmodule BoardWeb.Plugs.RequireAuth do
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
    else
      conn
      |> BoardWeb.ApiError.send(401, "UNAUTHORIZED", "로그인이 필요합니다.")
      |> halt()
    end
  end
end
