defmodule BoardWeb.Plugs.FetchUser do
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    user =
      case get_session(conn, :user_id) do
        nil -> nil
        id -> Board.Accounts.get_user(id)
      end

    assign(conn, :current_user, user)
  end
end
