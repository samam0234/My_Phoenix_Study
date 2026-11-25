defmodule Board.BlogTest do
  use Board.DataCase, async: false

  alias Board.Accounts
  alias Board.Blog

  setup do
    {:ok, user, _token} =
      Accounts.register_user(%{
        "email" => "writer@example.com",
        "password" => "password123",
        "nickname" => "writer"
      })

    %{user: user}
  end

  test "validates title and lists with meta", %{user: user} do
    assert {:error, changeset} = Blog.create_post(user, %{"title" => "", "body" => "본문"})
    assert "필수입니다." in errors_on(changeset).title

    assert {:ok, post} =
             Blog.create_post(user, %{"title" => "첫 글", "body" => "안녕하세요", "tags" => ["intro"]})

    {posts, meta} = Blog.list_posts(%{"limit" => "1"})
    assert meta.total == 1
    assert meta.limit == 1
    assert meta.page == 1
    assert hd(posts).id == post.id
    assert hd(posts).comment_count == 0
  end

  test "comment updates the count", %{user: user} do
    {:ok, post} = Blog.create_post(user, %{"title" => "글", "body" => "본문"})
    assert {:ok, _comment} = Blog.create_comment(user, post, %{"body" => "댓글"})
    assert Blog.get_post(post.id).comment_count == 1
  end
end
