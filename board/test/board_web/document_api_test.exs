defmodule BoardWeb.DocumentApiTest do
  use BoardWeb.ConnCase, async: false

  test "summarize and answer from the document text", %{conn: conn} do
    {conn, _token, _user} = signup_conn(conn)

    created =
      post(conn, "/api/documents", %{
        "filename" => "memo.md",
        "text" => "Phoenix LiveView는 서버가 화면 상태를 가진다. 게시판 예제."
      })

    document = json_response(created, 201)["data"]
    assert document["summary"] =~ "요약:"

    asked =
      post(recycle_auth(created, conn), "/api/documents/#{document["id"]}/questions", %{
        "question" => "LiveView는 어디에 상태를 두나요?"
      })

    answer = json_response(asked, 200)["data"]["answer"]
    assert answer =~ "발췌"
  end

  test "stream returns sse tokens", %{conn: conn} do
    {conn, _token, _user} = signup_conn(conn)
    conn = post(conn, "/api/ai/summarize/stream", %{"text" => "실시간 게시판"})
    assert response(conn, 200) =~ "data:"
    assert get_resp_header(conn, "content-type") |> hd() =~ "text/event-stream"
  end

  defp recycle_auth(conn, original) do
    token =
      original
      |> get_req_header("authorization")
      |> hd()
      |> String.replace_prefix("Bearer ", "")

    conn
    |> recycle()
    |> put_req_header("authorization", "Bearer " <> token)
    |> put_req_header("accept", "application/json")
  end
end
