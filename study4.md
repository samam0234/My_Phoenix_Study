# study4 · 라우팅과 요청 처리

**① 목표**  
URL, 동적 경로, 쿼리, 요청에서 응답까지의 흐름, 없는 주소의 오류 페이지를 연결한다.

## ② 📖 이론

### 왜 쓰는지

이용자는 화면 이름 대신 주소로 도착한다. `/posts/3`과 `/api/posts/3`은 같은 글이라도 응답 형식이 다르다. 라우터가 파이프라인으로 HTML과 JSON을 가른다.

### 핵심 개념

- **pipeline**: 공통 plug 묶음. `:browser`는 세션과 CSRF, `:api`는 JSON과 토큰.
- **scope**: 경로 접두어. `/api` 아래는 JSON 컨트롤러.
- **동적 조각** `:id`: `Params.id/1`이 양의 정수만 통과시킨다.
- **verified route** `~p"/posts/#{post.id}"`: 없는 경로는 컴파일할 때 드러난다.
- **쿼리**: `?q=첫&page=1&limit=10`은 `params` 맵으로 들어온다.

### 비유

라우터는 건물 안내 데스크다. `/posts/new`는 접수 창구, `/posts/3`은 3번 방, `/api/posts/3`은 같은 방의 주문서 사본이다. 안내 데스크가 없는 층 이름을 들으면 404 안내문을 준다.

## ③ 🛠️ 실기

### 전체 코드

`board/lib/board_web/router.ex`의 브라우저 Live 경로 순서:

```elixir
live "/posts", PostLive.Index, :index
live "/posts/new", PostLive.Form, :new
live "/posts/:id", PostLive.Show, :show
live "/posts/:id/edit", PostLive.Form, :edit
```

`/posts/new`가 `/posts/:id`보다 위에 있다. 반대면 `"new"`가 id로 잡힌다.

없는 HTML 주소는 `ErrorHTML`의 `404.html.heex`가 "페이지를 찾을 수 없습니다"를 보여 준다. 없는 JSON 주소는 `ErrorJSON`이 `error.code = "NOT_FOUND"`를 준다. API에서 id가 숫자가 아니면 컨트롤러가 `400 BAD_REQUEST`를 돌려준다. id는 숫자인데 글이 없으면 `404 NOT_FOUND`다.

쿼리에서 목록으로 가는 함수는 `Board.Pagination.parse/1`이다.

```elixir
def parse(params) when is_map(params) do
  page = params |> fetch("page") |> positive_or(1)
  limit = params |> fetch("limit") |> limit_or_default()
  %__MODULE__{
    page: page,
    limit: limit,
    offset: (page - 1) * limit,
    q: params |> fetch("q") |> blank_nil(),
    sort: params |> fetch("sort") |> allowed_sort()
  }
end
```

LiveView 검색은 `push_patch`로 같은 `/posts`에 쿼리만 바꾼다. 브라우저 주소와 API의 `GET /api/posts?q=`가 같은 키 `q`, `page`, `limit`, `sort`를 쓴다.

### 줄별 설명

| 줄 | 설명 |
| --- | --- |
| `live "/posts"` | GET이며 LiveView 프로세스를 연다. 액션 이름은 `:index` |
| `live "/posts/new"` | 고정 문자 `new`. 동적 조각보다 먼저 |
| `live "/posts/:id"` | 세 번째 조각이 `params["id"]` |
| `live ".../edit"` | `:edit` 액션. 같은 `PostLive.Form`이 `live_action`으로 새 글/수정을 가른다 |
| `positive_or(1)` | 0, 음수, 글자는 1페이지 |
| `limit` 상한 50 | 51 이상은 50. 기본은 10 |
| `offset` | `(page - 1) * limit`. 1페이지는 0부터 |
| `allowed_sort` | `createdAt`, `-createdAt`, `-commentCount`만. 나머지는 `-createdAt` |
| `~p` | 라우터에 없는 경로를 쓰면 컴파일이 실패한다 |

요청 흐름은 `Endpoint plug` → 라우터 매칭 → 파이프라인 plug → 컨트롤러 또는 LiveView → 컨텍스트 → JSON 또는 HEEx다.

## ④ 🔗 연동 포인트

프론트의 목록 주소와 백엔드 `GET /api/posts`는 쿼리 이름을 공유한다. 화면의 "다음" 링크는 `~p"/posts?#{%{page: @meta.page + 1, q: @q}}"`라서 페이지 이동이 라우터를 다시 탄다. API는 같은 번호의 글을 `Location: /api/posts/{id}` 헤더로 알려 준다. 이 경로가 곧 상세 GET이다.

## ⑤ 오류 노트

| 증상 | 원인 | 해결 |
| --- | --- | --- |
| `/posts/new`가 빈 상세로 감 | `/:id`가 위에 있음 | `new` 라우트를 동적 조각보다 위에 둔다 |
| `no route found for path` 컴파일 오류 | `~p` 오타 | 라우터에 있는 경로만 쓴다 |
| HTML 요청이 JSON 404 | `accept` 헤더가 json | 브라우저 주소창은 HTML 파이프라인이다 |
| 쿼리 `page=0`이 오류 | 잘못된 값을 거절하지 않고 기본값으로 바꿈 | 스펙대로 1로 보정한다. 테스트로 기대를 고정한다 |

## ⑥ 직접 해보기

1. `/posts/new`와 `/posts/1`이 다른 화면인지 확인한다.
2. `/nowhere`와 `/api/posts/abc`의 상태 코드가 404와 400으로 다른지 개발자 도구 또는 `curl`로 본다.
3. `/posts?page=2&q=안녕`으로 들어가 목록 함수가 쿼리를 읽는지 로그에 `handle_params`를 잠깐 넣어 확인한 뒤 지운다.

## ⑦ ☐ 체크리스트

- [ ] 고정 경로와 `:id` 순서를 지켰다
- [ ] 쿼리 `q`, `page`, `limit`, `sort`가 목록에 반영된다
- [ ] HTML 404와 JSON 404/400을 구분했다
- [ ] `~p` 경로와 API `Location`이 같은 글 번호로 맞는다

## ⑧ 다음 단계

주소가 글을 가리키면 [study5.md](study5.md)에서 그 주소로 보내는 입력값 검증과 상태 코드별 화면을 만든다.
