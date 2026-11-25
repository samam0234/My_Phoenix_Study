defmodule BoardWeb.PageController do
  use BoardWeb, :controller

  def home(conn, _params) do
    render(conn, :home, current_user: conn.assigns[:current_user])
  end

  def hello(conn, params) do
    name = params["name"] || "Phoenix"

    render(conn, :hello,
      current_user: conn.assigns[:current_user],
      name: name,
      greeting: Board.Syntax.greet(name),
      slug: Board.Syntax.pipeline_demo(name),
      samples: [
        {1, Board.Syntax.classify(1)},
        {0, Board.Syntax.classify(0)},
        {-3, Board.Syntax.classify(-3)}
      ]
    )
  end
end
