defmodule BoardWeb.ErrorHTMLTest do
  use BoardWeb.ConnCase, async: true

  import Phoenix.Template, only: [render_to_string: 4]

  test "renders 404.html" do
    assert render_to_string(BoardWeb.ErrorHTML, "404", "html", []) =~ "페이지를 찾을 수 없습니다"
  end

  test "renders 500.html" do
    assert render_to_string(BoardWeb.ErrorHTML, "500", "html", []) =~ "서버 오류가 발생했습니다"
  end
end
