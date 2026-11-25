defmodule BoardWeb.DocumentLive.Index do
  use BoardWeb, :live_view

  alias Board.Documents

  @impl true
  def mount(_params, _session, socket) do
    documents =
      if socket.assigns.current_user do
        Documents.list_documents(socket.assigns.current_user)
      else
        []
      end

    {:ok, assign(socket, page_title: "문서", documents: documents)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <h1 class="text-2xl font-semibold">문서 요약</h1>
      <p>txt 또는 md 파일을 올리면 요약이 붙습니다. 질문 답은 문서 발췌만 근거로 합니다.</p>
      <form
        :if={@current_user}
        id="upload-form"
        action={~p"/documents"}
        method="post"
        enctype="multipart/form-data"
        class="space-y-2"
      >
        <input type="hidden" name="_csrf_token" value={Phoenix.Controller.get_csrf_token()} />
        <input type="file" name="file" accept=".txt,.md,.markdown" required />
        <button class="btn btn-primary">올리기</button>
      </form>
      <p :if={!@current_user}><a href={~p"/login"}>로그인 후 문서를 올릴 수 있습니다.</a></p>
      <ul>
        <li :for={document <- @documents}>
          <a href={~p"/documents/#{document.id}"}>{document.filename}</a>
        </li>
      </ul>
    </Layouts.app>
    """
  end
end

defmodule BoardWeb.DocumentLive.Show do
  use BoardWeb, :live_view

  alias Board.Documents

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, question: "", answer: nil, sources: [])}
  end

  @impl true
  def handle_params(%{"id" => id}, _uri, socket) do
    user = socket.assigns.current_user

    cond do
      is_nil(user) ->
        {:noreply, socket |> put_flash(:error, "로그인이 필요합니다.") |> push_navigate(to: ~p"/login")}

      true ->
        case BoardWeb.Params.id(id) do
          {:ok, id} ->
            case Documents.get_document(user, id) do
              nil ->
                {:noreply,
                 socket |> put_flash(:error, "없는 문서입니다.") |> push_navigate(to: ~p"/documents")}

              document ->
                {:noreply,
                 socket
                 |> assign(:page_title, document.filename)
                 |> assign(:document, document)
                 |> assign(:history, Documents.list_questions(document))}
            end

          :error ->
            {:noreply, push_navigate(socket, to: ~p"/documents")}
        end
    end
  end

  @impl true
  def handle_event("ask", %{"question" => question}, socket) do
    case Documents.ask(socket.assigns.document, question) do
      {:ok, saved} ->
        {:noreply,
         socket
         |> assign(:question, "")
         |> assign(:answer, saved.answer)
         |> assign(:sources, saved.sources)
         |> assign(:history, Documents.list_questions(socket.assigns.document))}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "질문을 처리하지 못했습니다.")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <a href={~p"/documents"}>문서 목록</a>
      <h1 class="text-2xl font-semibold">{@document.filename}</h1>
      <h2 class="font-semibold">요약</h2>
      <p id="summary">{@document.summary || "요약을 만드는 중입니다."}</p>
      <form id="ask-form" phx-submit="ask" class="space-y-2">
        <textarea name="question" class="textarea textarea-bordered w-full">{@question}</textarea>
        <button class="btn btn-primary" phx-disable-with="답변 중...">질문</button>
      </form>
      <p :if={@answer} id="answer">{@answer}</p>
      <h2 class="font-semibold">지난 질문</h2>
      <ul id="history">
        <li :for={item <- @history}>{item.question} — {item.answer}</li>
      </ul>
    </Layouts.app>
    """
  end
end
