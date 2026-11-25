defmodule BoardWeb.UserAuth do
  import Phoenix.Component

  def on_mount(:mount_current_user, _params, session, socket) do
    user =
      case session["user_id"] do
        nil -> nil
        id -> Board.Accounts.get_user(id)
      end

    {:cont, assign(socket, :current_user, user)}
  end

  def on_mount(:ensure_authenticated, params, session, socket) do
    {:cont, socket} = on_mount(:mount_current_user, params, session, socket)

    if socket.assigns.current_user do
      {:cont, socket}
    else
      socket =
        socket
        |> Phoenix.LiveView.put_flash(:error, "로그인이 필요합니다.")
        |> Phoenix.LiveView.redirect(to: "/login")

      {:halt, socket}
    end
  end

  def session_token(user_id) do
    Phoenix.Token.sign(BoardWeb.Endpoint, "session", user_id)
  end

  def safe_path(path) when is_binary(path) do
    if String.starts_with?(path, "/") and not String.starts_with?(path, "//") and
         not String.contains?(path, "://") do
      path
    else
      "/posts"
    end
  end

  def safe_path(_path), do: "/posts"
end
