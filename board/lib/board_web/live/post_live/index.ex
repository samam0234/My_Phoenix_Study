defmodule BoardWeb.PostLive.Index do
  use BoardWeb, :live_view

  alias Board.Blog

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Phoenix.PubSub.subscribe(Board.PubSub, "posts")
    {:ok, stream(socket, :posts, [])}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {posts, meta} = Blog.list_posts(params)

    {:noreply,
     socket
     |> assign(:page_title, "게시판")
     |> assign(:meta, meta)
     |> assign(:q, params["q"] || "")
     |> stream(:posts, posts, reset: true)}
  end

  @impl true
  def handle_event("search", %{"q" => q}, socket) do
    {:noreply, push_patch(socket, to: ~p"/posts?#{%{q: q}}")}
  end

  @impl true
  def handle_info({:post_created, post}, socket) do
    if socket.assigns.q == "" and socket.assigns.meta.page == 1 do
      {:noreply, stream_insert(socket, :posts, post, at: 0)}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:post_updated, post}, socket) do
    {:noreply, stream_insert(socket, :posts, post)}
  end

  def handle_info({:post_deleted, post}, socket) do
    {:noreply, stream_delete(socket, :posts, post)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="flex items-center justify-between">
        <h1 class="text-2xl font-semibold">게시판</h1>
        <.link href={~p"/posts/new"} class="btn btn-primary">글쓰기</.link>
      </div>
      <form id="post-search" phx-change="search">
        <input
          type="text"
          name="q"
          value={@q}
          placeholder="제목·본문 검색"
          phx-debounce="300"
          class="input input-bordered w-full"
        />
      </form>
      <p :if={@meta.total == 0}>글이 없습니다.</p>
      <div id="posts" phx-update="stream" class="space-y-3">
        <article :for={{id, post} <- @streams.posts} id={id} class="rounded-box border p-4">
          <a href={~p"/posts/#{post.id}"} class="font-semibold">{post.title}</a>
          <p class="mt-1">{post.body}</p>
          <p class="text-sm opacity-70">
            {post.author.nickname} · 댓글 {post.comment_count}
          </p>
        </article>
      </div>
      <div class="flex gap-2">
        <.link :if={@meta.page > 1} href={~p"/posts?#{%{page: @meta.page - 1, q: @q}}"}>이전</.link>
        <span>{@meta.page} / {max(@meta.totalPages, 1)}</span>
        <.link
          :if={@meta.page < @meta.totalPages}
          href={~p"/posts?#{%{page: @meta.page + 1, q: @q}}"}
        >
          다음
        </.link>
      </div>
    </Layouts.app>
    """
  end
end
