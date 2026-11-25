defmodule BoardWeb.HealthController do
  use BoardWeb, :controller

  def show(conn, _params) do
    json(conn, %{status: "ok"})
  end
end
