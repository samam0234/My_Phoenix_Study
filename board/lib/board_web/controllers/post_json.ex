defmodule BoardWeb.PostJSON do
  alias Board.Blog.Post

  def index(%{posts: posts, meta: meta}) do
    %{data: Enum.map(posts, &data/1), meta: meta}
  end

  def show(%{post: post}), do: %{data: data(post)}

  def data(%Post{} = post) do
    %{
      id: post.id,
      title: post.title,
      body: post.body,
      tags: post.tags || [],
      author: author(post.author),
      commentCount: post.comment_count || 0,
      createdAt: iso(post.inserted_at),
      updatedAt: iso(post.updated_at)
    }
  end

  defp author(nil), do: nil
  defp author(user), do: %{id: user.id, nickname: user.nickname}

  defp iso(nil), do: nil

  defp iso(%DateTime{} = datetime),
    do: datetime |> DateTime.truncate(:second) |> DateTime.to_iso8601()
end
