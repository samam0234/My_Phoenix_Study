# study2 · 핵심 구조

**① 목표**  
Phoenix의 기본 단위인 컨텍스트, 컨트롤러, LiveView, HEEx, 라우터가 서로 함수와 assign으로 데이터를 넘기는 모습을 직접 만든다.

## ② 📖 이론

### 왜 쓰는지

한 파일에 화면, 검증, SQL을 같이 두면 고칠 때마다 전체가 흔들린다. Phoenix는 일을 **컨텍스트**(도메인 함수)와 **웹**(요청을 받는 쪽)으로 나눈다.

### 핵심 개념

- **컨텍스트** `Board.Blog`: 게시글을 만들고 지우는 함수. 웹을 모른다.
- **컨트롤러** `PostController`: HTTP를 컨텍스트 호출로 바꾼다.
- **LiveView** `PostLive.Index`: 연결이 살아있는 동안 소켓에 화면 상태를 둔다.
- **HEEx**: LiveView `render/1` 안의 `~H` 템플릿.
- **라우터**: URL을 위 모듈의 함수로 보낸다.
- **생명주기**: `mount` → `handle_params` → `render`. 사용자 클릭은 `handle_event`. 다른 프로세스 소식은 `handle_info`.

### 비유

컨텍스트는 주방, 컨트롤러와 LiveView는 홀 직원, 라우터는 입구 안내, HEEx는 손님에게 보이는 접시다. 홀 직원은 주방에 `create_post/2`를 주문하고, 접시에는 돌아온 구조체만 올린다.

## ③ 🛠️ 실기

### 전체 코드

라우터의 브라우저 구간은 `get "/"`, `get "/hello"`, 그리고 `live "/posts"`를 `PostLive.Index`로 연결한다. `live_session`의 `on_mount`가 세션의 `user_id`를 `:current_user` assign으로 넣는다.

LiveView 목록의 뼈대는 다음이다. 파일은 `board/lib/board_web/live/post_live/index.ex`.

```elixir
def mount(_params, _session, socket) do
  if connected?(socket), do: Phoenix.PubSub.subscribe(Board.PubSub, "posts")
  {:ok, stream(socket, :posts, [])}
end

def handle_params(params, _uri, socket) do
  {posts, meta} = Blog.list_posts(params)
  {:noreply,
   socket
   |> assign(:page_title, "게시판")
   |> assign(:meta, meta)
   |> assign(:q, params["q"] || "")
   |> stream(:posts, posts, reset: true)}
end

def handle_event("search", %{"q" => q}, socket) do
  {:noreply, push_patch(socket, to: ~p"/posts?#{%{q: q}}")}
end

def handle_info({:post_created, post}, socket) do
  {:noreply, stream_insert(socket, :posts, post, at: 0)}
end
```

템플릿은 `<Layouts.app flash={@flash} current_user={@current_user}>`로 감싸고, `phx-update="stream"` 목록에서 `post.title`을 보여 준다. 레이아웃은 `current_user`를 받아 닉네임 또는 로그인 링크를 그린다. 이것이 단위 사이의 데이터 전달이다. 세션 → `on_mount` → assign → HEEx.

### 줄별 설명

| 줄 | 설명 |
| --- | --- |
| mount 1행 | 인자는 쓰지 않아도 순서는 params, session, socket 이다 |
| mount 2행 | `connected?/1`이 참일 때만 구독한다. 첫 정적 렌더에서는 거짓이라 구독이 두 번 생기지 않는다 |
| mount 3행 | `stream`은 목록 각 항목에 DOM id를 붙이는 소켓 상태다 |
| handle_params | URL이 바뀔 때마다 호출된다. 검색어가 여기로 들어온다 |
| `Blog.list_posts` | 웹이 컨텍스트를 부른다. SQL은 컨텍스트 안에만 있다 |
| assign 연쇄 | 파이프로 소켓에 제목, 메타, 검색어를 넣는다 |
| `stream(..., reset: true)` | 이전 목록을 지우고 이번 조회 결과로 다시 채운다 |
| handle_event | 화면의 `phx-change="search"`가 이 함수를 부른다. 이벤트 이름이 첫 인자 |
| `push_patch` | 전체 새로고침 없이 URL만 바꾼다. 그러면 `handle_params`가 다시 돈다 |
| handle_info | 컨텍스트가 방송한 `{:post_created, post}` 튜플을 받는다 |
| `stream_insert at: 0` | 새 글을 목록 맨 앞에 끼운다 |

컨트롤러는 요청마다 죽고, LiveView 프로세스는 연결 동안 남는다. 같은 `Board.Blog`를 둘 다 부른다.

## ④ 🔗 연동 포인트

`assign(:current_user, user)`는 study7 로그인 세션이 채운다. `stream`에 들어가는 게시글 구조체는 study3의 Ecto 스키마다. `push_patch`의 쿼리는 study4 라우팅과 같은 URL이다. 컨텍스트가 돌려준 `{:ok, post}`는 study6 JSON의 `data`로 직렬화된다.

## ⑤ 오류 노트

| 증상 | 원인 | 해결 |
| --- | --- | --- |
| `cannot compile module ... get_csrf_token/0` | LiveView에 컨트롤러 함수가 자동으로 임포트되지 않음 | `Phoenix.Controller.get_csrf_token/0`처럼 전체 이름으로 부른다 |
| `key :current_user not found` | `on_mount` 없이 템플릿이 assign을 읽음 | `live_session`에 `UserAuth`를 건다 |
| 클릭이 서버에 안 감 | `phx-click` 이름과 `handle_event` 문자열이 다름 | 두 문자열을 같게 맞춘다 |
| 목록이 비어 보임 | stream id가 없거나 `phx-update="stream"`이 빠짐 | 컨테이너 id와 `id={id}`를 같이 둔다 |

## ⑥ 직접 해보기

1. `/posts`에서 검색창에 글자를 넣고 주소창 쿼리가 바뀌는지 본다.
2. `handle_event`의 `"search"`를 `"find"`로 잠깐 바꾸고 검색이 멈추는 것을 확인한 뒤 되돌린다.
3. 레이아웃의 게시판 링크가 `~p"/posts"`인지 소스에서 찾는다. 없는 경로면 컴파일 오류가 난다.

## ⑦ ☐ 체크리스트

- [ ] 컨텍스트 `Board.Blog`와 웹 `BoardWeb.PostLive`를 구분했다
- [ ] `mount`, `handle_params`, `handle_event`, `handle_info`가 언제 도는지 말했다
- [ ] assign과 HEEx `{@...}`로 데이터가 화면에 닿는 것을 봤다
- [ ] 📌 노션 원문: 라우터, 컨트롤러, HEEx 템플릿

## ⑧ 다음 단계

구조를 나눴으면 [study3.md](study3.md)에서 그 구조 안의 데이터, 즉 소켓 assign과 Ecto 스키마, 브라우저 초안 저장을 다룬다.
