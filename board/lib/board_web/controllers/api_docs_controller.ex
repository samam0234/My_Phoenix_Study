defmodule BoardWeb.ApiDocsController do
  use BoardWeb, :controller

  def index(conn, _params) do
    html(conn, """
    <!DOCTYPE html>
    <html lang="ko">
      <head><meta charset="utf-8"><title>Board API</title></head>
      <body>
        <h1>Board API 문서</h1>
        <p>OpenAPI JSON: <a href="/api-docs/openapi.json">/api-docs/openapi.json</a></p>
        <p>헬스 체크: <a href="/health">/health</a></p>
      </body>
    </html>
    """)
  end

  def spec(conn, _params) do
    path = Path.join(:code.priv_dir(:board), "openapi.json")

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, File.read!(path))
  end
end
