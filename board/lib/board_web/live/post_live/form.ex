defmodule BoardWeb.PostLive.Form do
  use BoardWeb, :live_view

  alias Board.Blog
  alias Board.Blog.Post

  @impl true
  def mount(_params, _session, socket) do
    if socket.assigns.current_user do
      {:ok, assign(socket, :submitting, false)}
    else
      {:ok,
       socket
       |> put_flash(:error, "로그인이 필요합니다.")
       |> redirect(to: ~p"/login")}
    end
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, _params) do
    post = %Post{}

    socket
    |> assign(:page_title, "새 글")
    |> assign(:post, post)
    |> assign(:form, to_form(Blog.change_post(post)))
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    case BoardWeb.Params.id(id) do
      {:ok, id} ->
        case Blog.get_post(id) do
          nil ->
            socket |> put_flash(:error, "없는 글입니다.") |> push_navigate(to: ~p"/posts")

          post ->
            if post.author_id == socket.assigns.current_user.id do
              socket
              |> assign(:page_title, "글 수정")
              |> assign(:post, post)
              |> assign(:form, to_form(Blog.change_post(post)))
            else
              socket
              |> put_flash(:error, "수정할 수 없습니다.")
              |> push_navigate(to: ~p"/posts/#{post.id}")
            end
        end

      :error ->
        socket |> put_flash(:error, "없는 글입니다.") |> push_navigate(to: ~p"/posts")
    end
  end

  @impl true
  def handle_event("validate", %{"post" => params}, socket) do
    form =
      socket.assigns.post
      |> Blog.change_post(params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, :form, form)}
  end

  def handle_event("save", %{"post" => params}, socket) do
    socket = assign(socket, :submitting, true)
    save(socket, socket.assigns.live_action, params)
  end

  defp save(socket, :new, params) do
    case Blog.create_post(socket.assigns.current_user, params) do
      {:ok, post} ->
        {:noreply,
         socket
         |> put_flash(:info, "글을 등록했습니다.")
         |> push_navigate(to: ~p"/posts/#{post.id}")}

      {:error, changeset} ->
        {:noreply,
         assign(socket, form: to_form(Map.put(changeset, :action, :insert)), submitting: false)}
    end
  end

  defp save(socket, :edit, params) do
    case Blog.update_post(socket.assigns.post, params) do
      {:ok, post} ->
        {:noreply,
         socket
         |> put_flash(:info, "글을 수정했습니다.")
         |> push_navigate(to: ~p"/posts/#{post.id}")}

      {:error, changeset} ->
        {:noreply,
         assign(socket, form: to_form(Map.put(changeset, :action, :update)), submitting: false)}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <h1 class="text-2xl font-semibold">{@page_title}</h1>
      <.form for={@form} id="post-form" phx-change="validate" phx-submit="save" class="space-y-3">
        <div :if={@live_action == :new} id="draft-title" phx-hook="DraftTitle">
          <.input field={@form[:title]} type="text" label="제목" />
        </div>
        <.input :if={@live_action != :new} field={@form[:title]} type="text" label="제목" />
        <.input field={@form[:body]} type="textarea" label="본문" />
        <.input field={@form[:tags_text]} type="text" label="태그 (쉼표로 구분)" />
        <button class="btn btn-primary" phx-disable-with="저장 중..." disabled={@submitting}>
          저장
        </button>
      </.form>
    </Layouts.app>
    """
  end
end
