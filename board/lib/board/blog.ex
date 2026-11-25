defmodule Board.Blog do
  @moduledoc """
  게시글과 댓글. 저장에 성공하면 PubSub과 채널로 알린다.
  """

  import Ecto.Query
  alias Board.Accounts.User
  alias Board.Blog.{Cache, Comment, Post}
  alias Board.Pagination
  alias Board.Repo

  def list_posts(params) when is_map(params) do
    page = Pagination.parse(params)

    loader = fn ->
      {rows, total} = fetch_rows(page)
      {hydrate(rows), Pagination.meta(page, total)}
    end

    if cacheable?(page), do: Cache.fetch("posts:first", loader), else: loader.()
  end

  def get_post(id) when is_integer(id) do
    case Repo.get(Post, id) do
      nil -> nil
      post -> hydrate_one(post)
    end
  end

  def change_post(%Post{} = post, attrs \\ %{}) do
    attrs = stringify(attrs)
    text = Map.get(attrs, "tags_text", tags_to_text(post.tags))

    post
    |> Post.changeset(normalize_attrs(Map.put(attrs, "tags_text", text)))
    |> Ecto.Changeset.put_change(:tags_text, text)
    |> mirror_tag_errors()
  end

  def create_post(%User{} = user, attrs) do
    %Post{}
    |> Post.changeset(normalize_attrs(attrs))
    |> Ecto.Changeset.put_change(:author_id, user.id)
    |> Repo.insert()
    |> after_post(:post_created)
  end

  def update_post(%Post{} = post, attrs) do
    post
    |> Post.changeset(normalize_attrs(attrs))
    |> Repo.update()
    |> after_post(:post_updated)
  end

  def delete_post(%Post{} = post) do
    case Repo.delete(post) do
      {:ok, post} ->
        Cache.invalidate("posts:first")
        broadcast_post(:post_deleted, %{post | comment_count: post.comment_count || 0})
        {:ok, post}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def list_comments(post_id) do
    Repo.all(
      from c in Comment,
        where: c.post_id == ^post_id,
        order_by: [asc: c.id],
        preload: [:author]
    )
  end

  def change_comment(%Comment{} = comment, attrs \\ %{}) do
    Comment.changeset(comment, attrs)
  end

  def create_comment(%User{} = user, %Post{} = post, attrs) do
    %Comment{}
    |> Comment.changeset(attrs)
    |> Ecto.Changeset.put_change(:author_id, user.id)
    |> Ecto.Changeset.put_change(:post_id, post.id)
    |> Repo.insert()
    |> case do
      {:ok, comment} ->
        comment = Repo.preload(comment, :author)
        Phoenix.PubSub.broadcast(Board.PubSub, "comments:#{post.id}", {:comment_created, comment})
        _ = after_post({:ok, Repo.get!(Post, post.id)}, :post_updated)
        {:ok, comment}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def get_comment(id) when is_integer(id) do
    case Repo.get(Comment, id) do
      nil -> nil
      comment -> Repo.preload(comment, :author)
    end
  end

  def delete_comment(%Comment{} = comment) do
    case Repo.delete(comment) do
      {:ok, comment} ->
        Phoenix.PubSub.broadcast(
          Board.PubSub,
          "comments:#{comment.post_id}",
          {:comment_deleted, comment}
        )

        if post = Repo.get(Post, comment.post_id) do
          _ = after_post({:ok, post}, :post_updated)
        end

        {:ok, comment}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  defp fetch_rows(page) do
    counts =
      from c in Comment,
        group_by: c.post_id,
        select: %{post_id: c.post_id, count: count(c.id)}

    query =
      from p in Post,
        left_join: cc in subquery(counts),
        on: cc.post_id == p.id

    query = apply_search(query, page)
    total = Repo.aggregate(count_query(page), :count)

    rows =
      query
      |> apply_sort(page)
      |> offset(^page.offset)
      |> limit(^page.limit)
      |> select([p, cc], {p, coalesce(cc.count, 0)})
      |> Repo.all()

    {rows, total}
  end

  defp count_query(page) do
    apply_search(from(p in Post), page)
  end

  defp apply_search(query, %{q: nil}), do: query

  defp apply_search(query, %{q: q}) do
    pattern = like_pattern(q)

    from p in query,
      where:
        fragment("? LIKE ? ESCAPE '\\'", p.title, ^pattern) or
          fragment("? LIKE ? ESCAPE '\\'", p.body, ^pattern)
  end

  defp apply_sort(query, %{sort: "createdAt"}) do
    from [p, cc] in query, order_by: [asc: p.inserted_at, asc: p.id]
  end

  defp apply_sort(query, %{sort: "-commentCount"}) do
    from [p, cc] in query, order_by: [desc: coalesce(cc.count, 0), desc: p.id]
  end

  defp apply_sort(query, _page) do
    from [p, cc] in query, order_by: [desc: p.inserted_at, desc: p.id]
  end

  defp hydrate(rows) do
    posts = Enum.map(rows, &elem(&1, 0))
    counts = Map.new(rows, fn {post, count} -> {post.id, count} end)

    posts
    |> Repo.preload(:author)
    |> Enum.map(fn post -> %{post | comment_count: Map.get(counts, post.id, 0)} end)
  end

  defp hydrate_one(post) do
    count =
      Repo.aggregate(from(c in Comment, where: c.post_id == ^post.id), :count)

    %{Repo.preload(post, :author) | comment_count: count}
  end

  defp after_post({:ok, post}, event) do
    post = hydrate_one(post)
    Cache.invalidate("posts:first")
    broadcast_post(event, post)
    {:ok, post}
  end

  defp after_post(error, _event), do: error

  defp broadcast_post(event, post) do
    Phoenix.PubSub.broadcast(Board.PubSub, "posts", {event, post})

    BoardWeb.Endpoint.broadcast("posts:lobby", Atom.to_string(event), %{
      id: post.id,
      title: post.title
    })

    :ok
  end

  defp cacheable?(%{page: 1, limit: 10, q: nil, sort: "-createdAt"}), do: true
  defp cacheable?(_page), do: false

  defp normalize_attrs(attrs) do
    attrs = stringify(attrs)

    cond do
      Map.has_key?(attrs, "tags_text") ->
        Map.put(attrs, "tags", split_tags(attrs["tags_text"]))

      Map.has_key?(attrs, "tags") ->
        Map.update!(attrs, "tags", &normalize_tag_value/1)

      true ->
        attrs
    end
  end

  defp normalize_tag_value(tags) when is_list(tags) do
    tags |> Enum.map(&to_string/1) |> Enum.map(&String.trim/1) |> Enum.reject(&(&1 == ""))
  end

  defp normalize_tag_value(tags) when is_binary(tags), do: split_tags(tags)
  defp normalize_tag_value(_tags), do: []

  defp split_tags(text) when is_binary(text) do
    text |> String.split(",") |> Enum.map(&String.trim/1) |> Enum.reject(&(&1 == ""))
  end

  defp split_tags(_text), do: []

  defp tags_to_text(nil), do: ""
  defp tags_to_text(tags), do: Enum.join(tags, ", ")

  defp stringify(attrs) when is_map(attrs) do
    Map.new(attrs, fn {key, value} -> {to_string(key), value} end)
  end

  defp mirror_tag_errors(changeset) do
    Enum.reduce(Keyword.get_values(changeset.errors, :tags), changeset, fn {message, opts}, acc ->
      Ecto.Changeset.add_error(acc, :tags_text, message, opts)
    end)
  end

  defp like_pattern(q) do
    escaped =
      q
      |> String.replace("\\", "\\\\")
      |> String.replace("%", "\\%")
      |> String.replace("_", "\\_")

    "%#{escaped}%"
  end
end
