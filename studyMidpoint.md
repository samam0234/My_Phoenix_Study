# studyMidpoint · 게시판과 로그인

**① 목표**  
study0부터 study10까지로만 게시판, 로그인, CRUD를 한 서비스로 돌리고 1차 배포 점검까지 한다.

## ② 📖 이론

### 왜 쓰는지

기능을 파일마다 따로 보면 로그인 없이 글이 써지는지, 지운 글이 API와 화면에서 같이 사라지는지 놓친다. 중간 응용은 배운 것만 이어 붙여 작은 서비스를 완성하는 자리다.

### 핵심 개념

배운 것만 쓴다. LiveView 화면, 세션 로그인, Bearer API, SQLite, changeset, 페이지네이션, HEEx. 결제, 캐시 서버, 다른 언어 화면은 넣지 않는다.

### 비유

기초 공부가 부품이면 이 문서는 그 부품으로 책상 하나를 조립하는 설명서다. 서랍을 나중에 다는 일(study11 이후)은 아직 하지 않는다.

## ③ 🛠️ 실기

### 기능 목록

- 회원가입, 로그인, 로그아웃, 내 정보
- 글 목록, 검색, 페이지, 상세
- 로그인 사용자만 작성, 작성자만 수정·삭제
- 댓글 작성
- `GET/POST/PATCH/DELETE /api/posts`와 댓글 API
- `/health`

### 폴더

```text
board/lib/board/accounts.ex
board/lib/board/blog.ex
board/lib/board_web/router.ex
board/lib/board_web/live/post_live/
board/lib/board_web/live/auth_live.ex
board/lib/board_web/controllers/post_controller.ex
board/lib/board_web/controllers/auth_controller.ex
board/priv/repo/migrations/20261126120000_create_board_tables.exs
```

### 구현 순서

1. study0 서버가 `http://localhost:4000`에서 뜬다.
2. `mix ecto.setup`으로 테이블과 시드(`mina@example.com` / `password123`, 첫 글)를 만든다.
3. `/signup`에서 계정을 만든다. 세션 쿠키로 `/posts/new`가 열린다.
4. 제목, 본문, 태그를 저장하면 상세로 이동한다.
5. 다른 브라우저(시크릿)에서 같은 목록을 본다. 실시간은 study17에서 붙인다. 지금은 새로고침으로 확인한다.
6. `/me`에서 API 토큰을 발급한다.
7. 토큰으로 `POST /api/posts`, `GET /api/posts?page=1`을 호출해 `data`와 `meta`를 확인한다.
8. 시드 계정이 아닌 토큰으로 그 글을 PATCH 해 403을 확인한다.
9. 작성자 토큰으로 DELETE 해 204, 화면 새로고침 시 글이 없는 것을 확인한다.

`mix phx.gen.live Blog Post posts title:string body:text`는 Index, Show, Form LiveView를 생성한다. 우리 화면은 그 세 모듈과 같은 역할이다.

- `PostLive.Index` 목록과 검색
- `PostLive.Show` 상세, 삭제, 댓글
- `PostLive.Form` 작성, 수정, 검증

생성기 코드를 읽고 싶다면 위 명령을 다른 폴더에서 실행한 뒤 `index.ex`, `show.ex`, `form.ex`의 `handle_event("save"`와 우리 파일을 나란히 둔다. 이 저장소 파일은 스펙 v1 JSON과 세션 로그인을 위해 그 뼈대를 유지한 채 손으로 정리한 것이다.

### DB·API 구성

```text
브라우저 /posts  --세션 쿠키-->  PostLive  --+
                                            +--> Board.Blog --> Board.Repo --> SQLite
API /api/posts   --Bearer----->  PostController --+
```

환경 변수는 개발에서 `.env`의 `PORT`, `CORS_ORIGIN`이고 DB 파일은 `config/dev.exs`다.

### 1차 배포 점검

- [ ] `curl /health`가 `{"status":"ok"}`
- [ ] 회원가입 후 글이 새로고침 뒤에도 남는다
- [ ] 비로그인 `/posts/new`는 로그인으로 간다
- [ ] 빈 제목은 저장되지 않는다
- [ ] API 목록에 `meta.page`, `meta.total`이 있다
- [ ] 비밀 키와 `.env`가 커밋되지 않았다

### 회고

기초만으로도 목록과 권한이 된다. 아쉬운 점은 다른 브라우저에 글이 즉시 나타나지 않는 것, DB가 SQLite 한 파일이라는 것, 화면 구성이 Phoenix 기본 컴포넌트 안에 있다는 것이다. 각각 study17, study11, study12에서 넓힌다. 인증 없는 공개 쓰기나 다른 프레임워크 화면은 여기에 붙이지 않는다.

## ④ 🔗 연동 포인트

중간 지점의 산출물은 `users`, `posts`, `comments` 테이블과 `/api/posts`다. study11은 Repo 어댑터만 바꾸고, study14는 이 경로를 OpenAPI로 적고, study17은 같은 `Board.Blog` 방송으로 목록을 민다. 중간 산출물을 깨지 않고 뒤에 덧붙이는 것이 심화의 조건이다.

## ⑤ 오류 노트

| 증상 | 원인 | 해결 |
| --- | --- | --- |
| 시드 계정이 없음 | `ecto.setup` 전에 서버만 실행 | `mix ecto.setup` |
| 글쓰기 버튼이 로그인으로 보냄 | 세션이 없음 | `/login` 후 다시 |
| API와 화면 숫자가 다름 | 다른 DB 파일 | dev 서버와 테스트 DB를 구분한다 |
| 403 대신 200 | 같은 계정으로 PATCH | 두 번째 계정 토큰을 쓴다 |

## ⑥ 직접 해보기

1. 시크릿 창과 일반 창으로 작성자와 다른 사용자를 나누어 403을 재현한다.
2. 댓글을 단 뒤 상세의 댓글 수와 API `commentCount`가 같은지 본다.
3. 1차 배포 점검 목록을 체크한 날짜를 한 줄 적는다.

## ⑦ ☐ 체크리스트

- [ ] 기능 목록의 화면 경로를 모두 열어 봤다
- [ ] API CRUD와 화면 CRUD가 같은 DB를 본다
- [ ] 1차 배포 점검을 수행했다
- [ ] 📌 노션 원문: `mix phx.gen.live`로 게시판 LiveView CRUD를 생성하고 코드 읽기
- [ ] 회고에 아직 없는 기능(실시간, 다른 DB)을 적었다

## ⑧ 다음 단계

같은 서비스를 유지한 채 DB부터 넓히는 글이 [study11.md](study11.md)다.
