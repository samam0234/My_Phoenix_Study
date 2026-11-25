defmodule BoardWeb.CommentController do
  use BoardWeb, :controller

  alias Board.Blog
  alias BoardWeb.Params
  action_fallback BoardWeb.FallbackController

  def index(conn, %{"id" => post_id}) do
    with {:ok, post_id} <- Params.id(post_id),
         %{} = post <- Blog.get_post(post_id) do
      render(conn, :index, comments: Blog.list_comments(post.id))
    else
      :error -> {:error, :bad_request}
      nil -> {:error, :not_found}
    end
  end

  def create(conn, %{"id" => post_id} = params) do
    attrs = Map.take(params, ["body"])

    with {:ok, post_id} <- Params.id(post_id),
         %{} = post <- Blog.get_post(post_id),
         {:ok, comment} <- Blog.create_comment(conn.assigns.current_user, post, attrs) do
      conn |> put_status(:created) |> render(:show, comment: comment)
    else
      :error -> {:error, :bad_request}
      nil -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  def delete(conn, %{"id" => id}) do
    with {:ok, id} <- Params.id(id),
         %{} = comment <- Blog.get_comment(id),
         :ok <- authorize(conn, comment),
         {:ok, _comment} <- Blog.delete_comment(comment) do
      send_resp(conn, :no_content, "")
    else
      :error -> {:error, :bad_request}
      nil -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  defp authorize(conn, comment) do
    case conn.assigns.current_user do
      %{id: id} when id == comment.author_id -> :ok
      nil -> {:error, :unauthorized}
      _user -> {:error, :forbidden}
    end
  end
end
