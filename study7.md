# study7 · 인증과 보안 기초

**① 목표**  
회원가입, 로그인, 세션과 API 토큰, 작성자 권한, 비밀번호 해시, CORS, XSS, CSRF를 한 앱에서 연결한다.

## ② 📖 이론

### 왜 쓰는지

공개 게시판이라도 수정과 삭제는 작성자만 해야 한다. 비밀번호를 그대로 저장하면 데이터베이스가 유출되는 순간 계정이 끝난다. 브라우저는 쿠키 세션으로, API 클라이언트는 Bearer 토큰으로 같은 `users` 행을 가리킨다.

### 핵심 개념

- **해시**: `Bcrypt.hash_pwd_salt/1`. 응답과 로그에 원문 비밀번호를 넣지 않는다.
- **세션**: 서명된 쿠키의 `user_id`. LiveView `on_mount`가 사용자를 찾는다.
- **토큰**: 원문은 한 번만 보여 주고, DB에는 SHA-256만 저장한다. 수명은 7일이다.
- **권한**: `author_id`가 아니면 403.
- **CORS**: `CORS_ORIGIN` 환경 변수 한 곳만 허용한다.
- **XSS**: HEEx가 본문을 이스케이프한다.
- **CSRF**: 브라우저 파이프라인의 `:protect_from_forgery`. API는 쿠키 대신 Authorization 헤더라 브라우저 폼 CSRF와 경로가 다르다.

### 비유

세션 쿠키는 매표소 도장, Bearer 토큰은 일회용 팔찌의 번호다. 팔찌 원본은 손님만 가지고 창고에는 번호의 지문만 둔다. 해시되지 않은 비밀번호는 창고에 열쇠 묶음을 적어 두는 일이다.

## ③ 🛠️ 실기

### 전체 코드의 흐름

1. `POST /api/auth/signup` `{email, password, nickname}` → 201 `{data: {user, accessToken}}`.
2. `POST /api/auth/login` → 200 같은 모양. 실패는 401 `INVALID_CREDENTIALS`. 이메일과 비밀번호 중 어디가 틀렸는지 말하지 않는다. 없는 이메일도 `Bcrypt.no_user_verify/0`로 시간을 맞춘다.
3. `GET /api/auth/me`는 `Authorization: Bearer <token>`.
4. `POST /api/auth/logout`은 토큰 행을 지우고 204.
5. 브라우저 `/login`은 `verify_password/2` 뒤 `Phoenix.Token`을 60초짜리 세션 교환 토큰으로 만들고 `/session/adopt`가 쿠키를 심는다.
6. `next`는 `/`로 시작하는 경로만 허용한다. `//`와 `https://`는 `/posts`로 바꾼다.
7. `/me`에서 "API 토큰 발급"을 누르면 브라우저 세션 사용자가 API 토큰을 하나 더 받는다. 같은 사용자 행이다.

`mix phx.gen.auth Accounts User users`는 세션, 비밀번호 해시, 로그인 화면, 토큰 테이블을 생성한다. 이 저장소는 그 생성기가 만드는 개념을 `Board.Accounts`와 `UserToken`으로 직접 적어 스펙의 Bearer 응답에 맞췄다. 생성기를 따로 돌려 파일을 읽고 싶다면 빈 폴더에서 명령을 실행한 뒤 `user_token`, `session`, 해시 함수가 어디 있는지 우리 `accounts.ex`와 나란히 보면 된다.

CORS plug는 허용 출처, 메서드, `authorization` 헤더를 달고 `OPTIONS`는 204로 끝낸다.

XSS는 `/hello?name=<script>`가 태그를 실행하지 않는 테스트로 고정했다. 게시글 본문도 `{post.body}`라 태그가 글자다.

### 줄별 설명 (토큰)

| 줄 | 설명 |
| --- | --- |
| `strong_rand_bytes(32)` | 추측하기 어려운 원문 |
| `url_encode64` | 헤더에 넣기 쉬운 문자열 |
| `hash(:sha256, raw)` | DB에 저장하는 값. 유출되어도 원문 토큰은 복구되지 않는다 |
| `ago(7, "day")` | 학습용 만료. 스펙은 1시간, 학습은 7일까지 허용 |
| `delete_token` | 로그아웃이 그 해시를 지운다 |
| `safe_path` | 오픈 리다이렉트를 막는다 |
| `put_secure_browser_headers` | 브라우저 응답의 기본 보안 헤더 |
| 개발 `log_rounds: 4` | 회원가입이 너무 느리지 않게. 운영은 bcrypt 기본 12 |

## ④ 🔗 연동 포인트

브라우저 LiveView는 쿠키 세션의 `user_id`로 `current_user`를 만든다. API는 같은 사용자의 `accessToken`을 Authorization에 실어 `/api/auth/me`와 글 작성을 한다. 프런트와 백엔드가 공유하는 것은 토큰 문자열 자체가 아니라 **users 테이블의 한 행**이다. `/me`가 그 연결을 보여 준다. CORS 출처는 나중에 붙는 화면 개발 서버 `http://localhost:5173`을 `.env`의 `CORS_ORIGIN`으로 맞춘다.

## ⑤ 오류 노트

| 증상 | 원인 | 해결 |
| --- | --- | --- |
| 로그인했는데 API가 401 | 세션 쿠키를 API가 보지 않음 | Bearer를 헤더에 넣는다. 설계가 그렇다 |
| 토큰을 다시 볼 수 없음 | 원문은 저장하지 않음 | 새 토큰을 발급한다 |
| 다른 사이트로 튕김 | `next=https://...` | `safe_path/1`이 `/posts`로 되돌린다 |
| 브라우저 폼 403 CSRF | 토큰 없는 POST | `<.form>` 또는 `_csrf_token` hidden |
| 비밀번호가 응답에 있음 | user 맵을 통째로 JSON | `id`, `email`, `nickname`만 고른다 |

## ⑥ 직접 해보기

1. 잘못된 비밀번호와 없는 이메일이 같은 401 문장인지 비교한다.
2. `/me`에서 토큰을 발급해 `GET /api/auth/me`에 넣고, 로그아웃 후 같은 토큰이 401인지 본다.
3. `/hello?name=<script>alert(1)</script>` 소스에 실행 가능한 `<script>` 태그가 없는지 본다.

## ⑦ ☐ 체크리스트

- [ ] 회원가입, 로그인, 내 정보, 로그아웃
- [ ] 세션 쿠키와 Bearer 토큰이 같은 사용자를 가리킨다
- [ ] 비밀번호는 해시만 저장되고 응답에 없다
- [ ] 작성자만 수정·삭제, 그 외는 403
- [ ] CORS 출처가 환경 변수다
- [ ] HEEx 이스케이프와 브라우저 CSRF를 확인했다
- [ ] 📌 노션 원문: `mix phx.gen.auth`로 로그인

## ⑧ 다음 단계

인증이 여러 파일에 퍼져 있으면 [study8.md](study8.md)에서 폴더와 설정을 다시 정리한다.
