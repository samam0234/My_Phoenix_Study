# studyFinal · Phoenix로 서비스 닫기

**① 목표**  
중간 응용 게시판에 DB 교체 경계, 외부 입출력, 문서 AI, Docker와 자동 테스트, 보안 점검을 더해 Phoenix 한 앱으로 서비스를 닫는다.

## ② 📖 이론

### 왜 쓰는지

기초 산출물만으로는 내 컴퓨터에서만 글이 남는다. 심화는 그 글을 다른 DB로 옮길 자리, 파일과 메일, 문서 요약, 반복 배포를 같은 코드 경계 안에 넣는다. 프레임워크를 바꾸거나 화면을 다른 저장소와 합치지 않는다.

### 핵심 개념

- 사용자는 세션으로 화면을 보고, API는 Bearer로 같은 `users` 행을 본다.
- 글과 댓글은 `Board.Blog`, 문서는 `Board.Documents`다.
- 기본 DB는 SQLite다. Postgres와 MariaDB는 어댑터와 URL만 바꾸는 자리고, MongoDB는 별도 드라이버다.
- 배포 단위는 `mix release` 이미지이고, 합류 조건은 `mix test`다.

### 비유

중간 응용이 책상 하나라면 심화는 서랍(DB), 우편함(메일), 서류함(업로드), 방송(PubSub), 조리실(요약 워커)을 같은 책상에 다는 일이다. 조리실 레시피는 다른 가게 주방을 호출하지 않고 이 가게 함수만 쓴다.

## ③ 🛠️ 실기

### 기능 목록

- 회원가입, 로그인, 로그아웃, 내 정보, 연습용 OAuth 콜백
- 게시글 CRUD, 검색, 페이지, 댓글, 작성자만 수정·삭제
- `/api/posts`와 댓글, `{data, meta}`, `error.code`
- 다른 브라우저에 글과 댓글 반영
- txt, md 업로드, 요약, 발췌 근거 질문, SSE, MCP 두 도구
- `/health`, `/api-docs`, Docker, GitHub Actions

### 연동 구성

```text
브라우저 LiveView --세션--> BoardWeb
        |                      |
        | PubSub posts         +--> Board.Blog --> Repo (SQLite, 교체 시 Postgres/MariaDB)
        | posts:lobby 채널
API Bearer ------------------> PostController / AuthController
업로드·질문 -----------------> Board.Documents --> SummaryWorker --> AI.Client
                                                         mock | ollama | openai
MCP stdio -------------------> Board.MCP.Server ----+
```

MongoDB를 실험하면 `Board.Blog`의 검증과 저장 사이만 드라이버로 바꾼다. 기본 테스트 경로는 SQLite를 유지한다.

### 구현 순서

1. studyMidpoint까지 게시판과 로그인이 동작하는지 `/posts`와 `GET /api/posts`로 확인한다.
2. study11 메모대로 운영 DB를 바꿀지 정한다. 학습 배포는 `DATABASE_PATH=/data/board.db`로 둔다.
3. study13 메일함, md 업로드, `/auth/oauth/mock`을 한 번씩 통과시킨다.
4. study14 `/api-docs/openapi.json`과 실제 401, 400, 404가 같은 code인지 본다.
5. study15에서 첫 페이지를 두 번 읽고, 글을 만든 뒤 캐시가 지워지는지 본다.
6. study17에서 두 브라우저로 글과 댓글을 반영한다.
7. study18에서 문서를 올리고, 없는 단어 질문에 "문서에서 찾을 수 없습니다"가 나오는지 본다. `mix board.mcp`의 `initialize`를 확인한다.
8. study16 체크리스트로 이미지, 비밀, 백업, CI를 닫는다.

### 배포 체크리스트

- [ ] `mix test`가 로컬 또는 CI에서 통과했다
- [ ] `GET /health`가 200이다
- [ ] `SECRET_KEY_BASE`를 `mix phx.gen.secret`으로 바꿨다
- [ ] `.env`, DB 파일, `priv/uploads` 내용이 커밋에 없다
- [ ] 비로그인 글쓰기와 타인 글 수정이 막힌다
- [ ] 검증 오류가 400 `VALIDATION_ERROR`다
- [ ] 비밀번호가 평문으로 저장되지 않는다
- [ ] `AI_API_KEY`가 로그와 저장소에 없다
- [ ] 기본 `AI_DRIVER`는 mock이다
- [ ] `/data` 볼륨 백업을 한 번 복사했다
- [ ] OpenAPI와 라우터의 `/api/posts`가 같다
- [ ] 두 브라우저 실시간과 문서 요약이 배포한 주소에서도 된다

### 보안 점검

- 세션 쿠키와 API 토큰을 한 요청에 섞어 CSRF로 글을 쓰지 않는다. API는 Bearer만 본다.
- HEEx는 본문을 이스케이프한다. `raw`로 글 본문을 넣지 않는다.
- 로그인 폼은 CSRF 토큰을 포함한다.
- 리다이렉트는 `safe_path`로 앱 안 경로만 허용한다.
- 업로드 확장자와 10MB, UTF-8을 서버에서 다시 본다.
- 500 본문에 스택을 넣지 않는다.
- 가입·로그인 호출 횟수는 429로 막는다. 테스트에서는 꺼 둔다.

### 최종 회고

이 앱으로 확인한 것: LiveView가 화면 상태를 들고, Ecto가 검증과 저장을 나누고, 같은 컨텍스트를 세션과 Bearer가 같이 부른다는 점. SQLite 파일 하나와 ETS 캐시는 학습 속도와 단일 노드에 맞다. 서버를 여러 대 두면 캐시와 채널은 그 노드 안에만 있으므로, 그때 study11의 서버 DB와 PubSub 어댑터를 다시 고른다. 문서 AI는 DocuForge의 올리기·요약·발췌 답을 이 앱의 `/documents`로 가져왔고, 다른 구현의 HTTP 서버에는 붙이지 않았다. 인증이 없던 초안과 달리 문서는 사용자 소유로 두어 게시판 권한과 맞췄다. 생성기 `phx.gen.live`, `phx.gen.json`, `phx.gen.auth`의 뼈대는 읽고, 응답 모양은 공통 API 스펙에 맞게 이 저장소 코드로 유지했다.

## ④ 🔗 연동 포인트

닫힌 산출물은 `board/` 릴리즈와 `/api/posts`, `/api/documents`, `/api/ai/summarize/stream`, `mix board.mcp`다. 환경 변수는 `SECRET_KEY_BASE`, `DATABASE_PATH` 또는 `DATABASE_URL`, `PORT`, `CORS_ORIGIN`, `AI_DRIVER`, `AI_API_URL`, `AI_API_KEY`, `AI_MODEL`이다. 다음 사람이 이 서비스를 이으면 스펙의 `data`와 `error.code`를 유지한 채 경로를 추가한다.

## ⑤ 오류 노트

| 증상 | 원인 | 해결 |
| --- | --- | --- |
| 배포 후 500 | `SECRET_KEY_BASE` 누락 | compose 또는 호스트 환경 변수 |
| 글은 있는데 문서만 실패 | 로그인 전에 업로드 | `/login` 후 `/documents` |
| 실시간만 안 됨 | 릴리즈에 소켓 경로가 빠짐 | `/socket`과 `/live`가 같은 엔드포인트인지 |
| CI는 통과, 브라우저는 실패 | 테스트가 캐시와 제한을 끔 | 사람이 두 브라우저와 429를 따로 본다 |
| 요약이 항상 mock | 이미지에 `AI_DRIVER` 미설정 | 기본값이 mock인 것이 맞다. 바꿀 때만 환경 변수 |

## ⑥ 직접 해보기

1. 배포 체크리스트를 위에서부터 표시하고, 못 한 항목은 이유를 한 줄 적는다.
2. 시드가 아닌 계정으로 남의 글을 PATCH 해 403을 확인한다.
3. 문서 하나를 올린 뒤 MCP `summarize_document`와 화면 요약이 같은 드라이버를 쓰는지 환경 변수로 확인한다.

## ⑦ ☐ 체크리스트

- [ ] 기능 목록의 화면과 API를 한 번씩 호출했다
- [ ] DB는 SQLite로 두고 교체 절차는 study11에 있다
- [ ] 메일, 업로드, 연습용 OAuth를 통과했다
- [ ] 문서 요약과 "찾을 수 없습니다" 답을 확인했다
- [ ] Docker, 비밀, 백업, CI를 점검했다
- [ ] 보안 점검 일곱 줄을 코드에서 위치를 짚어 봤다

## ⑧ 다음 단계

이 저장소의 학습 경로는 여기까지다. 이어서 할 일은 운영 비밀을 바꾼 뒤 체크리스트에 날짜를 적고, 호환이 깨지는 API 변경만 `/api/v2`로 여는 것이다.
