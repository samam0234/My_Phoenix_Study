# study8 · 구조화와 재사용

**① 목표**  
폴더를 컨텍스트와 웹으로 유지하고, 페이지네이션·오류·경로 검사처럼 반복되는 코드를 모듈로 빼며, 개발과 운영 설정을 나눈다.

## ② 📖 이론

### 왜 쓰는지

게시글 컨트롤러와 댓글 컨트롤러가 id 검사와 오류 JSON을 각각 복사하면 상태 코드 하나를 바꿀 때 반을 놓친다. 설정이 `dev.exs`에만 있으면 운영 비밀이 저장소에 들어가거나, 개발 암호가 운영에 남는다.

### 핵심 개념

- **컨텍스트 폴더**: `lib/board/accounts`, `blog`, `documents`, `ai`, `jobs`.
- **웹 폴더**: `controllers`, `live`, `plugs`, `channels`.
- **공용 모듈**: `Board.Pagination`, `BoardWeb.ApiError`, `BoardWeb.Params`, `BoardWeb.UserAuth`.
- **설정 분리**: `config.exs` 공통, `dev.exs` 로컬 DB, `test.exs` 샌드박스, `prod.exs` SSL, `runtime.exs` 환경 변수.

### 비유

공용 모듈은 매장 계산대 옆에 둔 자 하나다. 직원마다 자를 따로 만들면 길이가 달라진다. `runtime.exs`는 가게 문 연 뒤에 붙이는 오늘의 가격표라서, 컴파일된 코드 안에 비밀을 구워 넣지 않는다.

## ③ 🛠️ 실기

### 폴더

```text
lib/board/accounts.ex          # 회원가입, 토큰
lib/board/blog.ex              # 글, 댓글, 방송
lib/board/pagination.ex        # page, limit, q, sort
lib/board/ai/client.ex         # mock, ollama, openai
lib/board_web/api_error.ex     # error 객체
lib/board_web/fallback_controller.ex
lib/board_web/plugs/           # CORS, 토큰, 요청 id, 호출 제한
lib/board_web/user_auth.ex     # on_mount, safe_path
```

`Params.id/1`은 컨트롤러 네 곳이 같이 쓴다. `ApiError.send/5`는 상태 코드와 `requestId`를 한곳에서 만든다. `UserAuth.safe_path/1`은 세션 교환과 테스트가 같이 쓴다.

개발과 운영:

| 파일 | 두는 것 |
| --- | --- |
| `dev.exs` | SQLite 파일, 코드 리로더, 개발용 `secret_key_base` |
| `test.exs` | 샌드박스 DB, 메일 테스트 어댑터, 서버 끔 |
| `prod.exs` | HTTPS 강제, 정적 파일 다이제스트 |
| `runtime.exs` | `PORT`, `DATABASE_PATH`, `SECRET_KEY_BASE`, `CORS_ORIGIN`, `AI_*` |

`runtime.exs`는 컴파일 뒤, 부팅 전에 실행된다. 그래서 이미지를 다시 안 만들어도 환경 변수만 바꿀 수 있다. 개발에서만 `.env`를 읽는다.

반복을 줄인 예: 글 작성자 확인은 `PostController`와 `CommentController`에 작은 `authorize/2`로 남아 있다. 조건은 같다. "로그인 사용자가 작성자인가." 오류 문장 자체는 폴백으로 보내 문장 중복을 막았다.

### 줄별 설명 (`runtime.exs` 개발 .env)

| 줄 | 설명 |
| --- | --- |
| `config_env() == :dev` | 테스트와 운영은 셸 환경 변수만 믿는다 |
| 빈 줄과 `#` | 주석과 공백은 건너뛴다 |
| `split "=", parts: 2` | 값 안의 `=`를 자르지 않는다 |
| `System.get_env(key) in [nil, ""]` | 이미 있는 변수를 파일로 덮지 않는다 |
| `config :board, :ai` | 드라이버와 모델. 코드에 키를 적지 않는다 |
| 운영 `DATABASE_PATH` | 없으면 raise. 잘못된 경로로 조용히 빈 파일을 만들지 않는다 |
| 운영 `SECRET_KEY_BASE` | 쿠키 서명. `mix phx.gen.secret` |

## ④ 🔗 연동 포인트

개발은 `mix phx.server`와 `board_dev.db`, 운영은 `PHX_SERVER=true`와 `DATABASE_PATH`, `SECRET_KEY_BASE`다. 테스트는 `test.exs`에서 캐시와 호출 제한을 끄고(`runtime.exs`가 `config_env() != :test`로 끈다) 샌드박스로 DB를 롤백한다. 같은 컨텍스트 함수를 세 환경이 부른다.

## ⑤ 오류 노트

| 증상 | 원인 | 해결 |
| --- | --- | --- |
| 운영에서 개발 비밀 키가 동작 | `dev.exs` 값을 prod가 읽음 | 운영 비밀은 `runtime.exs`의 환경 변수만 |
| `.env`를 고쳐도 테스트가 바뀜 | 테스트가 .env를 읽음 | 로더는 dev 전용이다. 테스트는 셸을 쓴다 |
| id 파싱이 컨트롤러마다 다름 | 복사된 함수 | `BoardWeb.Params`로 모은다 |
| 설정 변경이 반영 안 됨 | 릴리즈가 옛 환경으로 기동 | 프로세스를 다시 띄운다. 컴파일 타임 값은 `prod.exs`를 고친 뒤 다시 빌드 |

## ⑥ 직접 해보기

1. `lib/board`와 `lib/board_web`에서 `Repo.insert`가 웹 모듈에 없는지 검색한다. 쓰기는 컨텍스트에만 있어야 한다.
2. `runtime.exs`에서 `DATABASE_PATH`를 지운 채로 운영 부팅이 거절되는지 주석으로 경로를 확인하고, 실제 운영 기동은 study10에서 한다.
3. `ApiError.send`를 부르는 곳을 세어 상태 코드 문장이 흩어지지 않았는지 본다.

## ⑦ ☐ 체크리스트

- [ ] 도메인과 웹 폴더가 나뉘어 있다
- [ ] 페이지네이션, 오류 JSON, id 검사, 안전 경로가 공용 모듈이다
- [ ] dev, test, prod, runtime 설정이 역할대로 나뉜다
- [ ] 비밀과 DB 경로가 운영 환경 변수다

## ⑧ 다음 단계

구조가 고정되면 [study9.md](study9.md)에서 그 모듈을 테스트와 로그로 확인한다.
