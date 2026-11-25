defmodule BoardWeb.ApiTest do
  use BoardWeb.ConnCase, async: false

  test "health and posts follow spec v1", %{conn: conn} do
    assert json_response(get(conn, "/health"), 200) == %{"status" => "ok"}

    {conn, token, user} = signup_conn(build_conn())

    created_conn =
      post(conn, "/api/posts", %{"title" => "첫 글", "body" => "안녕하세요", "tags" => ["intro"]})

    created = json_response(created_conn, 201)["data"]
    assert get_resp_header(created_conn, "location") == ["/api/posts/#{created["id"]}"]
    assert created["author"]["nickname"] == user["nickname"]
    assert created["commentCount"] == 0

    list =
      created_conn
      |> auth(token)
      |> get("/api/posts?q=#{URI.encode_www_form("첫")}&page=1&limit=10")

    body = json_response(list, 200)
    assert hd(body["data"])["id"] == created["id"]
    assert body["meta"]["page"] == 1
    assert body["meta"]["q"] == "첫"
    assert body["meta"]["total"] == 1

    invalid = list |> auth(token) |> post("/api/posts", %{"title" => "", "body" => ""})
    error = json_response(invalid, 400)["error"]
    assert error["code"] == "VALIDATION_ERROR"
    assert error["fields"]["title"]
    assert error["requestId"]

    {other, _other_token, _other_user} = signup_conn(build_conn(), email: "other@example.com")
    forbidden = patch(other, "/api/posts/#{created["id"]}", %{"title" => "훔침"})
    assert json_response(forbidden, 403)["error"]["code"] == "FORBIDDEN"

    missing = auth(build_conn(), token) |> get("/api/posts/999999")
    assert json_response(missing, 404)["error"]["code"] == "NOT_FOUND"

    bad = auth(build_conn(), token) |> get("/api/posts/abc")
    assert json_response(bad, 400)["error"]["code"] == "BAD_REQUEST"

    comment =
      auth(build_conn(), token)
      |> post("/api/posts/#{created["id"]}/comments", %{"body" => "잘 읽었습니다"})

    assert json_response(comment, 201)["data"]["body"] == "잘 읽었습니다"

    deleted = auth(build_conn(), token) |> delete("/api/posts/#{created["id"]}")
    assert response(deleted, 204) == ""
  end

  test "login failure and me", %{conn: conn} do
    signup_conn(conn, email: "mina@example.com", nickname: "mina")

    failed =
      post(build_conn(), "/api/auth/login", %{
        "email" => "mina@example.com",
        "password" => "wrong-pass"
      })

    assert json_response(failed, 401)["error"]["code"] == "INVALID_CREDENTIALS"

    login =
      post(build_conn(), "/api/auth/login", %{
        "email" => "mina@example.com",
        "password" => "password123"
      })

    token = json_response(login, 200)["data"]["accessToken"]
    me = auth(build_conn(), token) |> get("/api/auth/me")
    payload = json_response(me, 200)["data"]
    assert payload["email"] == "mina@example.com"
    refute Map.has_key?(payload, "password_hash")
  end

  test "safe redirect rejects an external next" do
    assert BoardWeb.UserAuth.safe_path("/posts") == "/posts"
    assert BoardWeb.UserAuth.safe_path("https://evil.example") == "/posts"
    assert BoardWeb.UserAuth.safe_path("//evil.example") == "/posts"
  end

  defp auth(conn, token) do
    conn
    |> recycle()
    |> put_req_header("authorization", "Bearer " <> token)
    |> put_req_header("accept", "application/json")
  end
end
