defmodule BoardWeb.Plugs.Authenticate do
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    user =
      case bearer(conn) do
        nil -> nil
        token -> Board.Accounts.get_user_by_token(token)
      end

    assign(conn, :current_user, user)
  end

  defp bearer(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] when token != "" -> token
      _other -> nil
    end
  end
end
