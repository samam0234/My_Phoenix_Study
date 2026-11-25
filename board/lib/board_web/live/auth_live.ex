defmodule BoardWeb.AuthLive.Login do
  use BoardWeb, :live_view

  alias Board.Accounts
  alias BoardWeb.UserAuth

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "로그인",
       form: to_form(%{"email" => "", "password" => ""}, as: :user)
     )}
  end

  @impl true
  def handle_event("login", %{"user" => %{"email" => email, "password" => password}}, socket) do
    case Accounts.verify_password(email, password) do
      {:ok, user} ->
        token = UserAuth.session_token(user.id)

        {:noreply, redirect(socket, to: ~p"/session/adopt?#{%{token: token, next: "/posts"}}")}

      {:error, :invalid} ->
        {:noreply, put_flash(socket, :error, "이메일 또는 비밀번호가 올바르지 않습니다.")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <h1 class="text-2xl font-semibold">로그인</h1>
      <.form for={@form} id="login-form" phx-submit="login" class="space-y-3">
        <.input field={@form[:email]} type="email" label="이메일" />
        <.input field={@form[:password]} type="password" label="비밀번호" />
        <button class="btn btn-primary" phx-disable-with="확인 중...">로그인</button>
      </.form>
      <p><a href={~p"/signup"}>회원가입</a></p>
      <p><a href={~p"/auth/oauth/mock"}>연습용 소셜 로그인</a></p>
    </Layouts.app>
    """
  end
end

defmodule BoardWeb.AuthLive.Signup do
  use BoardWeb, :live_view

  alias Board.Accounts
  alias Board.Accounts.User
  alias BoardWeb.UserAuth

  @impl true
  def mount(_params, _session, socket) do
    form = %User{} |> Accounts.change_registration() |> to_form(as: :user)
    {:ok, assign(socket, page_title: "회원가입", form: form)}
  end

  @impl true
  def handle_event("validate", %{"user" => params}, socket) do
    form =
      %User{}
      |> Accounts.change_registration(params)
      |> Map.put(:action, :validate)
      |> to_form(as: :user)

    {:noreply, assign(socket, :form, form)}
  end

  def handle_event("save", %{"user" => params}, socket) do
    case Accounts.register_user(params) do
      {:ok, user, _token} ->
        token = UserAuth.session_token(user.id)

        {:noreply,
         socket
         |> put_flash(:info, "가입했습니다.")
         |> redirect(to: ~p"/session/adopt?#{%{token: token, next: "/posts"}}")}

      {:error, changeset} ->
        {:noreply,
         assign(socket, :form, to_form(Map.put(changeset, :action, :insert), as: :user))}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <h1 class="text-2xl font-semibold">회원가입</h1>
      <.form for={@form} id="signup-form" phx-change="validate" phx-submit="save" class="space-y-3">
        <.input field={@form[:email]} type="email" label="이메일" />
        <.input field={@form[:nickname]} type="text" label="닉네임" />
        <.input field={@form[:password]} type="password" label="비밀번호" />
        <button class="btn btn-primary" phx-disable-with="가입 중...">가입</button>
      </.form>
    </Layouts.app>
    """
  end
end

defmodule BoardWeb.AuthLive.Me do
  use BoardWeb, :live_view

  alias Board.Accounts

  @impl true
  def mount(_params, _session, socket) do
    if socket.assigns.current_user do
      {:ok, assign(socket, page_title: "내 정보", api_token: nil)}
    else
      {:ok, socket |> put_flash(:error, "로그인이 필요합니다.") |> redirect(to: ~p"/login")}
    end
  end

  @impl true
  def handle_event("issue_token", _params, socket) do
    {:ok, token} = Accounts.create_token(socket.assigns.current_user)
    {:noreply, assign(socket, :api_token, token)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <h1 class="text-2xl font-semibold">내 정보</h1>
      <p>브라우저 세션으로 로그인되어 있습니다. API는 아래 토큰을 Bearer로 보냅니다.</p>
      <p>이메일 {@current_user.email}</p>
      <p>닉네임 {@current_user.nickname}</p>
      <button id="issue-token" phx-click="issue_token" class="btn">API 토큰 발급</button>
      <p :if={@api_token}><code id="api-token">{@api_token}</code></p>
    </Layouts.app>
    """
  end
end
