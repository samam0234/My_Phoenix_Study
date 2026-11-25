defmodule BoardWeb.PostController do
  use BoardWeb, :controller

  alias Board.Blog
  alias BoardWeb.Params
  action_fallback BoardWeb.FallbackController

  def index(conn, params) do
    {posts, meta} = Blog.list_posts(params)
    render(conn, :index, posts: posts, meta: meta)
  end

  def show(conn, %{"id" => id}) do
    with {:ok, id} <- Params.id(id),
         %{} = post <- Blog.get_post(id) do
      render(conn, :show, post: post)
    else
      :error -> {:error, :bad_request}
      nil -> {:error, :not_found}
    end
  end

  def create(conn, params) do
    case Blog.create_post(conn.assigns.current_user, params) do
      {:ok, post} ->
        conn
        |> put_resp_header("location", ~p"/api/posts/#{post.id}")
        |> put_status(:created)
        |> render(:show, post: post)

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def update(conn, %{"id" => id} = params) do
    attrs = Map.drop(params, ["id"])

    with {:ok, id} <- Params.id(id),
         %{} = post <- Blog.get_post(id),
         :ok <- authorize(conn, post),
         {:ok, post} <- Blog.update_post(post, attrs) do
      render(conn, :show, post: post)
    else
      :error -> {:error, :bad_request}
      nil -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  def delete(conn, %{"id" => id}) do
    with {:ok, id} <- Params.id(id),
         %{} = post <- Blog.get_post(id),
         :ok <- authorize(conn, post),
         {:ok, _post} <- Blog.delete_post(post) do
      send_resp(conn, :no_content, "")
    else
      :error -> {:error, :bad_request}
      nil -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  defp authorize(conn, post) do
    case conn.assigns.current_user do
      %{id: id} when id == post.author_id -> :ok
      nil -> {:error, :unauthorized}
      _user -> {:error, :forbidden}
    end
  end
end
