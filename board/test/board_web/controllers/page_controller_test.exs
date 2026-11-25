defmodule BoardWeb.PageControllerTest do
  use BoardWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "서버가 화면 상태를 들고 있는 게시판"
  end

  test "GET /hello escapes the name", %{conn: conn} do
    conn = get(conn, ~p"/hello?name=#{URI.encode_www_form("<script>alert(1)</script>")}")
    body = html_response(conn, 200)
    assert body =~ "안녕하세요"
    refute body =~ "<script>alert"
  end
end
