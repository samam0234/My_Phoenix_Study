defmodule BoardWeb.Plugs.AssignRequestId do
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    request_id =
      conn
      |> get_resp_header("x-request-id")
      |> List.first() || Ecto.UUID.generate()

    conn
    |> put_resp_header("x-request-id", request_id)
    |> assign(:request_id, request_id)
  end
end
