# study17 · 실시간

**① 목표**  
글과 댓글이 저장되는 순간 PubSub으로 다른 LiveView와 채널 구독자에게 제목과 댓글을 보낸다.

## ② 📖 이론

### 왜 쓰는지

새로고침해야만 남의 글이 보이면 게시판이 아니다. Phoenix는 프로세스마다 구독만 해 두면, 저장에 성공한 함수가 주제로 메시지를 뿌린다. 화면 소켓과 일반 채널이 같은 저장 사건을 각각 받을 수 있다.

### 핵심 개념

- **PubSub**: `Board.PubSub`. 목록 주제 `"posts"`, 댓글 주제 `"comments:글id"`.
- **LiveView**: 소켓이 연결된 뒤에만 `subscribe`. `handle_info`가 stream에 행을 넣거나 뺀다.
- **채널**: `BoardWeb.UserSocket`의 `/socket`, 토픽 `posts:lobby`. 이벤트 이름 `post_created`.
- **페이로드**: 채널에는 `id`와 `title`만 보낸다. 본문 전체를 소켓에 뿌리지 않는다.

### 비유

PubSub은 매장 방송이다. 계산대가 저장에 성공하면 "새 글"이라고 방송하고, 그 채널을 틀어 둔 화면만 진열대를 고친다. 방송을 안 듣는 손님은 다음에 문을 열 때(새로고침) 본다.

## ③ 🛠️ 실기

저장 성공 뒤에만 방송한다.

```elixir
defp broadcast_post(event, post) do
  Phoenix.PubSub.broadcast(Board.PubSub, "posts", {event, post})

  BoardWeb.Endpoint.broadcast("posts:lobby", Atom.to_string(event), %{
    id: post.id,
    title: post.title
  })
end
```

| 줄 | 설명 |
| --- | --- |
| `"posts"` | LiveView 목록이 구독하는 주제 |
| `{event, post}` | `:post_created`, `:post_updated`, `:post_deleted`와 구조체 |
| `posts:lobby` | 브라우저 `channel`이 듣는 토픽 |
| `id`, `title` | 콘솔에 찍을 최소 필드 |

목록 `mount`는 정적 렌더가 아니라 소켓이 붙은 뒤에 구독한다.

```elixir
def mount(_params, _session, socket) do
  if connected?(socket), do: Phoenix.PubSub.subscribe(Board.PubSub, "posts")
  {:ok, stream(socket, :posts, [])}
end
```

`handle_info({:post_created, post}, socket)`는 검색어가 없고 1페이지일 때만 맨 위에 넣는다. 수정은 `stream_insert`, 삭제는 `stream_delete`다.

상세는 `"comments:#{post.id}"`를 구독한다. `{:comment_created, comment}`가 오면 댓글 stream에 추가한다. 다른 글의 댓글은 이 주제를 듣지 않는다.

브라우저 쪽은 `assets/js/app.js`가 `/socket`에 연결하고 `posts:lobby`에 join 한 뒤 `post_created`를 `console.log` 한다. LiveView 갱신과 별개로, 채널 수신을 확인할 때 쓴다.

알림을 메일로 넓힐 때는 study13 `UserNotifier`를 방송 수신 프로세스에서 호출할 수 있다. 이 단계의 알림은 화면 stream과 콘솔 로그다. 업로드 파일 처리는 study13에 있고, 여기서는 그 결과를 기다리지 않는다.

## ④ 🔗 연동 포인트

방송은 study6 `Board.Blog`가 저장에 성공한 뒤에만 나간다. changeset 오류면 다른 브라우저는 아무 것도 받지 않는다. 방송 직전에 study15 캐시 키를 지운다. 목록 LiveView는 이미 열린 소켓만 고치고, 새로 연 탭은 `list_posts`로 DB를 읽는다. API 클라이언트는 채널에 붙지 않아도 `GET /api/posts`로 같은 글을 본다.

## ⑤ 오류 노트

| 증상 | 원인 | 해결 |
| --- | --- | --- |
| 다른 탭이 안 바뀜 | 구독을 `connected?` 밖에서 함 | 연결 후에만 subscribe |
| 검증 실패인데 빈 글이 보임 | 방송이 insert 실패에도 나감 | `after_post`의 `{:ok, post}`만 방송 |
| 검색 중에 새 글이 끼어듦 | 1페이지 조건을 안 봄 | `q == ""`이고 `page == 1`일 때만 insert |
| 콘솔에 이벤트가 없음 | `/socket`이 아님 | `new Socket("/socket")`와 `posts:lobby` |
| 댓글이 다른 글에 붙음 | 주제가 `"posts"` 하나 | 상세는 `"comments:id"` |

## ⑥ 직접 해보기

1. 브라우저 두 개로 `/posts`를 열고, 한쪽에서 글을 쓴 뒤 다른 쪽이 새로고침 없이 행을 추가하는지 본다.
2. 같은 글 상세를 두 탭에서 열고 댓글을 달아 다른 탭 목록에 붙는지 본다.
3. 개발자도구 콘솔에서 `realtime post`와 제목이 출력되는지 확인한다.

## ⑦ ☐ 체크리스트

- [ ] 목록과 상세가 연결된 뒤에만 PubSub을 구독한다
- [ ] 저장 성공 뒤에만 글과 댓글 이벤트가 나간다
- [ ] 채널 페이로드는 id와 title뿐이다
- [ ] 📌 노션 원문: PubSub로 새 글과 댓글을 다른 브라우저에 실시간 반영
- [ ] 검색 중인 목록에는 새 글을 끼워 넣지 않는다

## ⑧ 다음 단계

실시간으로 쌓인 글을 읽는 다음 확장은 [study18.md](study18.md)의 문서 요약과 MCP다.
