defmodule BoardWeb.OauthController do
  use BoardWeb, :controller

  alias Board.Accounts
  alias BoardWeb.UserAuth

  def request(conn, _params) do
    redirect(conn, to: ~p"/auth/oauth/mock/callback?code=study")
  end

  def callback(conn, %{"code" => "study"}) do
    user = demo_user()
    token = UserAuth.session_token(user.id)
    redirect(conn, to: ~p"/session/adopt?token=#{token}&next=/posts")
  end

  def callback(conn, _params) do
    conn
    |> put_flash(:error, "소셜 로그인 코드가 올바르지 않습니다.")
    |> redirect(to: ~p"/login")
  end

  defp demo_user do
    email = "oauth-demo@example.com"

    case Accounts.get_user_by_email(email) do
      %{} = user ->
        user

      nil ->
        {:ok, user, _token} =
          Accounts.register_user(%{
            "email" => email,
            "password" => "password123",
            "nickname" => "oauth"
          })

        user
    end
  end
end
