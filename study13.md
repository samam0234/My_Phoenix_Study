# study13 · 외부 서비스 연동

**① 목표**  
메일, 파일 업로드, 소셜 로그인 흐름을 Phoenix 프로세스 안에서 각각 한 예제로 연결한다.

## ② 📖 이론

### 왜 쓰는지

회원가입 메일이 나가지 않으면 사용자는 가입 여부를 모른다. 문서 파일은 메모리에만 두면 요청이 끝나는 순간 사라진다. 소셜 로그인은 비밀번호 대신 공급자가 준 짧은 수명의 code를 우리 세션으로 바꾸는 왕복이다.

### 핵심 개념

- **Swoosh**: `Board.Accounts.UserNotifier`. 개발은 로컬 어댑터, `/dev/mailbox`에서 본다. 테스트는 `Swoosh.Adapters.Test`.
- **업로드**: `Plug.Upload`. 10MB 한도, 확장자는 `.txt`, `.md`, `.markdown`.
- **OAuth 연습**: `/auth/oauth/mock`이 code `study`로 콜백에 돌아온다. 운영 공급자 비밀은 환경 변수에만 둔다. 이 예제는 외부 회사로 나가지 않는다.

### 비유

메일은 등기 영수증, 업로드는 창구에 맡긴 서류, OAuth code는 다른 건물 안내가 끊어 준 번호표다. 번호표 자체를 계정으로 저장하지 않고, 우리 세션 도장으로 바꾼 뒤 번호표는 버린다.

## ③ 🛠️ 실기

### 메일

`UserNotifier.deliver_welcome/1`이 가입 직후 본문을 만든다. 실패해도 가입은 유지하고 경고 로그만 남긴다. 개발에서 `/dev/mailbox`를 연다. 운영 어댑터는 `runtime.exs` 주석의 Mailgun 예처럼 API 키를 환경 변수로 넣는다. 키를 소스에 적지 않는다.

### 파일

`POST /documents`의 `file` 필드 또는 API `{"filename","text"}`.

```elixir
def create_from_upload(%User{} = user, %Plug.Upload{} = upload) do
  extension = upload.filename |> Path.extname() |> String.downcase()
  # .txt .md .markdown 만, 10MB 초과면 {:error, :payload_too_large}
end
```

`Plug.Parsers`의 `length: 10_000_000`이 더 큰 본문을 413 `PAYLOAD_TOO_LARGE`로 막는다. 저장 파일은 프로세스 임시 경로에서 읽어 `documents.original_text`에 넣는다. 업로드 디렉터리 `priv/uploads`는 gitignore 한다.

### 소셜 로그인 연습

1. `GET /auth/oauth/mock`이 `/auth/oauth/mock/callback?code=study`로 리다이렉트한다.
2. 콜백이 `oauth-demo@example.com` 사용자를 만들거나 찾는다.
3. 60초 세션 토큰으로 `/session/adopt`에 가고 쿠키가 생긴다.
4. code가 `study`가 아니면 로그인 화면으로 돌려보낸다.

운영에서 공급자를 붙일 때는 이 컨트롤러의 code 검사를 환경 변수의 클라이언트 비밀번호로 교환하는 요청으로 바꾼다. 교환 전에 우리 DB에 임의의 관리자를 만들지 않는다. 예제 계정 비밀번호 `password123`은 로컬 연습용이다.

### 줄별 설명

| 줄 | 설명 |
| --- | --- |
| `from({"Board", "board@localhost"})` | 발신 주소. 운영에서는 실제 도메인 |
| `Mailer.deliver` | 어댑터가 Local이면 메모리, Test면 테스트 프로세스 |
| 가입 함수가 메일 실패를 무시 | 메일 장애로 계정 생성이 롤백되지 않게 |
| 확장자 검사 | 브라우저 MIME은 비어 있을 수 있어 확장자를 본다 |
| `String.valid?` | UTF-8이 아니면 400 |
| `code=study` | 공급자 없이 리다이렉트 모양만 연습 |
| `session_token` 60초 | code를 쿠키로 바꾸는 짧은 구간 |

## ④ 🔗 연동 포인트

업로드된 본문은 study18 요약의 입력이 된다. 메일의 수신자는 study7 사용자 이메일이다. OAuth가 만드는 세션은 게시판 `current_user`와 같다. 결제처럼 서명 검증이 필요한 웹훅을 붙일 때도 비밀은 `runtime.exs` 환경 변수로만 읽고, 본문 원문을 로그에 남기지 않는 같은 규칙을 쓴다.

## ⑤ 오류 노트

| 증상 | 원인 | 해결 |
| --- | --- | --- |
| 메일이 안 보임 | prod에서 Local 어댑터를 끔 | 개발은 `/dev/mailbox`. 운영은 API 키 |
| 413 | 10MB 초과 | 파일을 줄이거나 한도를 문서로만 조정 |
| txt가 400 | 인코딩이 UTF-8이 아님 | 에디터에서 UTF-8로 저장 |
| 콜백이 바로 로그인 실패 | code가 `study`가 아님 | 연습 경로는 `/auth/oauth/mock`에서 시작한다 |

## ⑥ 직접 해보기

1. 회원가입 후 `/dev/mailbox`에서 환영 메일을 연다.
2. `.md` 파일을 `/documents`에 올리고 상세에 파일 이름이 보이는지 확인한다.
3. `/auth/oauth/mock`으로 들어와 `/posts`에 닉네임 `oauth`가 보이는지 확인한다.

## ⑦ ☐ 체크리스트

- [ ] 개발 메일함에서 가입 메일을 봤다
- [ ] txt/md 업로드와 크기 제한을 확인했다
- [ ] 연습용 OAuth가 세션 로그인으로 이어진다
- [ ] 비밀과 API 키는 환경 변수 자리만 있고 소스에 없다

## ⑧ 다음 단계

외부로 나가는 입출력이 생기면 [study14.md](study14.md)에서 그 HTTP API의 규칙과 문서를 고정한다.
