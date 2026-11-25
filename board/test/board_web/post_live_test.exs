defmodule BoardWeb.PostLiveTest do
  use BoardWeb.ConnCase, async: false
  import Phoenix.LiveViewTest

  test "index renders an empty board", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/posts")
    assert html =~ "게시판"
  end

  test "login shows a generic error", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/login")

    html =
      render_submit(view, "login", %{
        "user" => %{"email" => "nope@example.com", "password" => "password123"}
      })

    assert html =~ "이메일 또는 비밀번호가 올바르지 않습니다."
  end
end
