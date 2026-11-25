defmodule BoardWeb.AuthController do
  use BoardWeb, :controller

  alias Board.Accounts
  action_fallback BoardWeb.FallbackController

  def signup(conn, params) do
    case Accounts.register_user(params) do
      {:ok, user, token} ->
        conn |> put_status(:created) |> render(:auth, user: user, token: token)

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def login(conn, %{"email" => _email, "password" => _password} = params) do
    case Accounts.authenticate(params["email"], params["password"]) do
      {:ok, user, token} -> render(conn, :auth, user: user, token: token)
      {:error, :invalid} -> {:error, :invalid_credentials}
    end
  end

  def login(_conn, _params), do: {:error, :bad_request}

  def logout(conn, _params) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] -> Accounts.delete_token(token)
      _other -> :ok
    end

    send_resp(conn, :no_content, "")
  end

  def me(conn, _params) do
    render(conn, :me, user: conn.assigns.current_user)
  end
end
