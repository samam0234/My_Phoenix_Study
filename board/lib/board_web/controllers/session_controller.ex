defmodule BoardWeb.SessionController do
  use BoardWeb, :controller

  alias BoardWeb.UserAuth

  def adopt(conn, %{"token" => token} = params) do
    case Phoenix.Token.verify(BoardWeb.Endpoint, "session", token, max_age: 60) do
      {:ok, user_id} ->
        conn
        |> put_session(:user_id, user_id)
        |> put_flash(:info, "로그인했습니다.")
        |> redirect(to: UserAuth.safe_path(params["next"]))

      {:error, _reason} ->
        conn
        |> put_flash(:error, "로그인 확인에 실패했습니다.")
        |> redirect(to: ~p"/login")
    end
  end

  def adopt(conn, _params) do
    redirect(conn, to: ~p"/login")
  end

  def delete(conn, _params) do
    conn
    |> configure_session(drop: true)
    |> put_flash(:info, "로그아웃했습니다.")
    |> redirect(to: ~p"/")
  end
end
