defmodule BoardWeb.PostLive.Show do
  use BoardWeb, :live_view

  alias Board.Blog
  alias Board.Blog.Comment

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket |> stream(:comments, []) |> assign(:form, to_form(Blog.change_comment(%Comment{})))}
  end

  @impl true
  def handle_params(%{"id" => id}, _uri, socket) do
    case BoardWeb.Params.id(id) do
      {:ok, id} ->
        case Blog.get_post(id) do
          nil ->
            {:noreply, socket |> put_flash(:error, "없는 글입니다.") |> push_navigate(to: ~p"/posts")}

          post ->
            if connected?(socket),
              do: Phoenix.PubSub.subscribe(Board.PubSub, "comments:#{post.id}")

            {:noreply,
             socket
             |> assign(:page_title, post.title)
             |> assign(:post, post)
             |> stream(:comments, Blog.list_comments(post.id), reset: true)}
        end

      :error ->
        {:noreply, socket |> put_flash(:error, "없는 글입니다.") |> push_navigate(to: ~p"/posts")}
    end
  end

  @impl true
  def handle_event("validate", %{"comment" => params}, socket) do
    form =
      %Comment{}
      |> Blog.change_comment(params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, :form, form)}
  end

  def handle_event("save", %{"comment" => params}, socket) do
    if socket.assigns.current_user do
      case Blog.create_comment(socket.assigns.current_user, socket.assigns.post, params) do
        {:ok, _comment} ->
          {:noreply, assign(socket, :form, to_form(Blog.change_comment(%Comment{})))}

        {:error, changeset} ->
          {:noreply, assign(socket, :form, to_form(Map.put(changeset, :action, :insert)))}
      end
    else
      {:noreply, put_flash(socket, :error, "댓글은 로그인 후 작성합니다.")}
    end
  end

  def handle_event("delete", _params, socket) do
    post = socket.assigns.post
    user = socket.assigns.current_user

    if user && user.id == post.author_id do
      {:ok, _} = Blog.delete_post(post)
      {:noreply, socket |> put_flash(:info, "삭제했습니다.") |> push_navigate(to: ~p"/posts")}
    else
      {:noreply, put_flash(socket, :error, "삭제할 수 없습니다.")}
    end
  end

  @impl true
  def handle_info({:comment_created, comment}, socket) do
    {:noreply, stream_insert(socket, :comments, comment)}
  end

  def handle_info({:comment_deleted, comment}, socket) do
    {:noreply, stream_delete(socket, :comments, comment)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <a href={~p"/posts"} class="text-sm">목록</a>
      <h1 class="text-2xl font-semibold">{@post.title}</h1>
      <p class="whitespace-pre-wrap">{@post.body}</p>
      <p class="text-sm opacity-70">
        {@post.author.nickname} · 태그 {Enum.join(@post.tags || [], ", ")}
      </p>
      <div class="flex gap-2">
        <.link
          :if={@current_user && @current_user.id == @post.author_id}
          href={~p"/posts/#{@post.id}/edit"}
          class="btn"
        >
          수정
        </.link>
        <button
          :if={@current_user && @current_user.id == @post.author_id}
          id="delete-post"
          phx-click="delete"
          data-confirm="이 글을 삭제할까요?"
          class="btn"
        >
          삭제
        </button>
      </div>
      <h2 class="text-xl font-semibold">댓글</h2>
      <div id="comments" phx-update="stream" class="space-y-2">
        <article :for={{id, comment} <- @streams.comments} id={id} class="rounded-box border p-3">
          <p>{comment.body}</p>
          <p class="text-sm opacity-70">{comment.author.nickname}</p>
        </article>
      </div>
      <.form
        for={@form}
        id="comment-form"
        phx-change="validate"
        phx-submit="save"
        class="space-y-2"
      >
        <.input field={@form[:body]} type="textarea" label="댓글" />
        <button class="btn btn-primary" phx-disable-with="등록 중...">등록</button>
      </.form>
    </Layouts.app>
    """
  end
end
