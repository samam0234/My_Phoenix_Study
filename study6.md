# study6 · DB와 API 연동

**① 목표**  
SQLite에 스키마와 마이그레이션을 두고, 게시글·댓글 CRUD를 공통 API 스펙 v1의 `/api/posts`에 맞춘다. 연결 정보는 환경 변수로 나눈다.

## ② 📖 이론

### 왜 쓰는지

화면만 있으면 서버를 재시작하면 글이 사라진다. Ecto Repo가 SQL을 대신 실행하고, 마이그레이션이 테이블 모양을 코드로 남긴다. JSON 모양을 스펙과 같게 두면 화면을 나중에 바꿔도 주소와 필드 이름이 유지된다.

### 핵심 개념

- **Repo**: `Board.Repo`. 개발 어댑터는 `Ecto.Adapters.SQLite3`.
- **마이그레이션**: `priv/repo/migrations/20261126120000_create_board_tables.exs`.
- **컨텍스트 함수**: `list_posts`, `get_post`, `create_post`, `update_post`, `delete_post`, 댓글 세 가지.
- **JSON 뷰**: `PostJSON`, `CommentJSON`. 키는 camelCase.
- **환경 변수**: 운영의 `DATABASE_PATH`, `POOL_SIZE`는 `config/runtime.exs`가 읽는다.

### 비유

마이그레이션은 책장 도면, 스키마는 책 한 권의 목차, Repo는 사서, JSON 뷰는 대출 카드에 적는 공개 정보다. 비밀번호 해시처럼 카드에 적지 않을 칸도 있다.

## ③ 🛠️ 실기

### 순서

1. `config/dev.exs`의 `database:` 경로, 운영은 `DATABASE_PATH`.
2. 마이그레이션으로 `users`, `user_tokens`, `posts`, `comments`, `documents`, `questions`.
3. `mix ecto.create && mix ecto.migrate`.
4. 컨텍스트에서 목록·상세·등록·수정·삭제.
5. 컨트롤러가 상태 코드와 `Location`을 붙인다.
6. 실패는 `FallbackController`.

### 목록 응답

`GET /api/posts?q=첫&page=1&limit=10`

```json
{
  "data": [
    {
      "id": 1,
      "title": "첫 글",
      "body": "안녕하세요",
      "tags": ["intro"],
      "author": {"id": 1, "nickname": "mina"},
      "commentCount": 0,
      "createdAt": "2026-11-26T00:00:00Z",
      "updatedAt": "2026-11-26T00:00:00Z"
    }
  ],
  "meta": {"page": 1, "limit": 10, "total": 1, "totalPages": 1, "q": "첫"}
}
```

### 동사

| 메서드 | 경로 | 성공 |
| --- | --- | --- |
| GET | `/health` | 200 `{status: ok}` |
| GET | `/api/posts` | 200 data+meta |
| GET | `/api/posts/:id` | 200 data |
| POST | `/api/posts` | 201, `Location` |
| PATCH | `/api/posts/:id` | 200, 작성자만 |
| DELETE | `/api/posts/:id` | 204 본문 없음 |
| GET | `/api/posts/:id/comments` | 200 |
| POST | `/api/posts/:id/comments` | 201 |
| DELETE | `/api/comments/:id` | 204 |

### 줄별 설명 (컨트롤러 `create`)

| 줄 | 설명 |
| --- | --- |
| `create_post(current_user, params)` | 작성자는 토큰의 사용자. body의 author는 받지 않는다 |
| `put_resp_header location` | 스펙의 `Location: /api/posts/{id}` |
| `put_status :created` | 201 |
| `render :show` | `PostJSON.show/1`이 `%{data: ...}` |
| `{:error, changeset}` | 폴백이 400과 `fields`로 변환 |

changeset 오류 변환은 `BoardWeb.ApiError.fields/1`이 `traverse_errors`로 `%{title: ["1~200자로 입력하세요."]}`를 만든다. 이메일 중복만 409 `EMAIL_TAKEN`이다.

`author_id`는 `put_change`로만 넣는다. cast 목록에 없으므로 클라이언트가 남의 id를 보낼 수 없다.

검색은 `LIKE ? ESCAPE`로 바인딩한다. 사용자 문자열을 SQL 조각에 이어 붙이지 않는다.

생성기와의 관계: `mix phx.gen.json Blog Post posts title:string body:text`는 컨트롤러 뼈대를 만든다. 그 뼈대는 `data`/`meta`와 `error.code`가 아니므로, 이 저장소는 생성기 결과를 스펙에 맞게 다시 쓴 `PostController`를 유지한다. 생성기 템플릿은 `deps/phoenix/priv/templates/phx.gen.json/`에서 읽어 비교할 수 있다.

## ④ 🔗 연동 포인트

`config/runtime.exs`의 운영 블록은 `DATABASE_PATH`가 없으면 부팅을 멈춘다. 개발은 `config/dev.exs`의 파일 경로를 쓴다. 토큰이 필요한 쓰기는 `:api_auth` 파이프라인이다. 목록과 상세는 공개 `:api`다. 화면 LiveView는 같은 `Board.Blog`를 쓰므로 API로 만든 글이 `/posts`에 나타난다. PubSub 방송은 study17에서 다른 브라우저로 이어진다.

## ⑤ 오류 노트

| 증상 | 원인 | 해결 |
| --- | --- | --- |
| `relation posts does not exist` 또는 no such table | 마이그레이션 전 | `mix ecto.migrate` |
| `DATABASE_PATH is missing` | 운영 부팅 | 환경 변수로 db 파일 경로를 준다 |
| 목록이 배열만 옴 | JSON 뷰가 스펙 이전 모양 | `%{data: ..., meta: ...}`로 감싼다 |
| 작성자가 요청 값으로 바뀜 | `author_id`를 cast함 | `put_change`만 사용 |
| 남의 글 수정이 200 | 권한 확인 누락 | `author_id`가 아니면 403 `FORBIDDEN` |

## ⑥ 직접 해보기

1. 회원가입 후 토큰으로 글을 만들고 `Location` 헤더의 주소로 GET 한다.
2. `limit=100`이 `meta.limit == 50`으로 줄어드는지 본다.
3. 다른 계정 토큰으로 PATCH 해 403을 확인한다.

## ⑦ ☐ 체크리스트

- [ ] 연결 설정과 `DATABASE_PATH`를 환경 변수로 나눴다
- [ ] 📌 노션 원문: Ecto 스키마, 마이그레이션, changeset 검증
- [ ] 목록, 상세, 등록, 수정, 삭제, 댓글이 동작한다
- [ ] 📌 노션 원문: `mix phx.gen.json`으로 `/api/posts` JSON API
- [ ] 📌 노션 원문: JSON 목록 응답을 `data`와 `meta`로
- [ ] 📌 노션 원문: changeset 오류를 `error.code` / `message` / `fields`로 변환
- [ ] 오류에 `requestId`가 있고 스택은 응답에 없다

## ⑧ 다음 단계

글을 누가 썼는지 알려면 [study7.md](study7.md)의 회원가입과 토큰이 필요하다.
