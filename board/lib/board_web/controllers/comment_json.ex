defmodule BoardWeb.CommentJSON do
  def index(%{comments: comments}) do
    %{
      data: Enum.map(comments, &data/1),
      meta: %{total: length(comments)}
    }
  end

  def show(%{comment: comment}), do: %{data: data(comment)}

  defp data(comment) do
    %{
      id: comment.id,
      postId: comment.post_id,
      body: comment.body,
      author: %{id: comment.author.id, nickname: comment.author.nickname},
      createdAt: comment.inserted_at |> DateTime.truncate(:second) |> DateTime.to_iso8601()
    }
  end
end
