defmodule BoardWeb.ErrorJSONTest do
  use BoardWeb.ConnCase, async: true

  test "renders 404" do
    body = BoardWeb.ErrorJSON.render("404.json", %{})
    assert body.error.code == "NOT_FOUND"
  end

  test "renders 500" do
    body = BoardWeb.ErrorJSON.render("500.json", %{})
    assert body.error.code == "INTERNAL"
    refute body.error.message =~ "stack"
  end
end
