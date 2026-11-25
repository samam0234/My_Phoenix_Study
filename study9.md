# study9 · 테스트와 디버깅

**① 목표**  
컨텍스트 단위 테스트와 HTTP 요청 테스트를 작성하고, 로그와 IEx로 실패를 보며, 자주 나는 오류를 한 목록으로 둔다.

## ② 📖 이론

### 왜 쓰는지

손으로 클릭한 기억은 다음 수정에서 사라진다. ExUnit은 회원가입이 해시를 남기는지, 목록이 `meta`를 가지는지, 다른 작성자가 403을 받는지를 매번 같은 순서로 확인한다.

### 핵심 개념

- **DataCase**: Repo와 샌드박스. `Board.AccountsTest`, `Board.BlogTest`.
- **ConnCase**: `get`, `post`, `json_response`. `BoardWeb.ApiTest`.
- **LiveViewTest**: `live/2`, `render_submit/2`.
- **샌드박스**: 테스트가 끝나면 DB 변경을 롤백한다. SQLite는 `async: false`.
- **mock**: AI는 `AI_DRIVER=mock`. 테스트가 외부 모델에 나가지 않는다. 캐시와 호출 제한도 테스트에서 꺼 둔다.
- **로그**: `config.exs`의 포맷에 `request_id`가 들어간다. 개발 중에는 `IO.inspect(value, label: "post")` 또는 `dbg/1`.

### 비유

테스트는 연습 경기 기록지다. 샌드박스는 경기가 끝나면 운동장을 원래 선으로 되돌리는 일이다. mock은 상대 팀 대신 세워 둔 마네킹이라 네트워크가 없어도 우리 동작만 확인한다.

## ③ 🛠️ 실기

### 실행

```bash
cd board
mix test
mix test test/board_web/api_test.exs
mix test test/board_web/api_test.exs:4
```

줄 번호는 그 테스트만 실행한다. 이 저장소의 현재 묶음은 19개이며 실패 0으로 확인했다.

### 요청 테스트가 하는 일

`BoardWeb.ApiTest`는 `/health`, 회원가입, 글 생성, `Location`, 목록 `meta`, 빈 제목 400, 다른 사용자 403, 없는 id 404, 글자 id 400, 댓글 201, 삭제 204를 한 테스트에서 잇는다. `signup_conn/2`가 토큰을 받아 다음 요청 헤더에 넣는다.

LiveView 테스트는 `/posts`에 "게시판"이 있는지, 틀린 로그인에 공통 문장이 있는지를 본다.

### DB를 가짜로

테스트는 진짜 SQLite 파일 `board_test.db`를 쓰되 샌드박스가 롤백한다. 외부 API는 가짜다.

```elixir
config :board, :ai, driver: "mock"
config :board, :cache_enabled, false
config :board, :rate_limit_enabled, false
```

`runtime.exs`가 테스트 환경에서 캐시와 제한을 끈다. `Board.AI.Client`는 driver가 `mock`이면 HTTP를 열지 않고 함수가 만든 문장을 돌려준다. 메일은 `Swoosh.Adapters.Test`라 바깥으로 나가지 않는다.

### 디버깅

- 터미널 로그의 `request_id`와 응답 JSON의 `requestId`를 맞춘다.
- `iex -S mix phx.server` 안에서 `Board.Blog.list_posts(%{})`를 호출한다.
- 브레이크포인트가 필요하면 함수에 `IEx.pry`를 넣고 `iex -S mix test`로 그 테스트만 실행한 뒤 지운다.
- LiveView는 브라우저 콘솔에서 `liveSocket.enableDebug()`.

### 자주 나는 오류 10

| # | 증상 | 원인 | 해결 |
| --- | --- | --- | --- |
| 1 | `no such table: posts` | 마이그레이션 전 | `mix ecto.migrate` |
| 2 | `database is locked` | 서버와 테스트가 같은 파일을 씀 | 서버를 끄거나 테스트 DB를 분리. 이미 `board_test.db`다 |
| 3 | `(FunctionClauseError) no function clause matching in handle_event` | 이벤트 이름 불일치 | `phx-submit` 문자열을 맞춘다 |
| 4 | `key :flash not found` | 레이아웃에 flash를 안 넘김 | `<Layouts.app flash={@flash}>` |
| 5 | CSRF 403 | 브라우저 POST에 토큰 없음 | `<.form>` 또는 hidden `_csrf_token` |
| 6 | 401인데 토큰을 넣었음 | `Bearer ` 접두어 누락 또는 로그아웃된 해시 | `Authorization: Bearer ...` |
| 7 | `** (ArgumentError) no route found` | `~p` 경로 오타 | 라우터와 철자를 맞춘다 |
| 8 | changeset이 늘 유효 | `action` 없이 오류를 숨김 | `:validate`를 넣는다 |
| 9 | 테스트가 이전 데이터를 봄 | `async: true`와 SQLite | DB 테스트는 `async: false` |
| 10 | NIF `make not found` | bcrypt 컴파일에 컴파일러 없음 | 빌드 도구 설치 후 `mix deps.compile bcrypt_elixir` |

## ④ 🔗 연동 포인트

테스트의 `post(conn, "/api/posts", ...)`는 운영과 같은 라우터와 컨텍스트를 탄다. DB만 샌드박스이고, AI만 mock이다. `Board.MCPTest`는 DB 없이 `Board.MCP.Server.handle_message/1`을 불러 study18 도구가 네트워크 없이 요약 문장을 만드는지 본다.

## ⑤ 오류 노트

| 증상 | 원인 | 해결 |
| --- | --- | --- |
| `json_response`가 상태 불일치로 실패 | 기대한 코드와 실제가 다름 | 메시지에 본문이 나온다. `error.code`를 읽는다 |
| 두 번째 요청이 멈춘 conn | `post` 결과를 그대로 `get` | `recycle/1` 후 헤더를 다시 넣는다 |
| pry가 안 열림 | `mix test`는 IEx가 아님 | `iex -S mix test` |

## ⑥ 직접 해보기

1. `mix test test/board/accounts_test.exs`만 실행해 해시와 중복 이메일을 확인한다.
2. 제목 검증 문장을 일부러 바꾸고 테스트가 실패하는지 본 뒤 되돌린다.
3. 실패 응답의 `requestId`를 서버 로그에서 찾는다.

## ⑦ ☐ 체크리스트

- [ ] 컨텍스트 테스트와 요청 테스트가 있다
- [ ] LiveView 테스트를 한 번 실행했다
- [ ] 테스트에서 DB는 샌드박스, AI는 mock이다
- [ ] `request_id` 로그와 `dbg`/`IO.inspect` 위치를 안다
- [ ] 위 10가지 증상 중 세 가지의 해결을 말로 설명할 수 있다

## ⑧ 다음 단계

테스트가 초록이면 [study10.md](study10.md)에서 그 앱을 빌드하고 기초 구간을 정리한다.
