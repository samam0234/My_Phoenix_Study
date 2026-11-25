# study16 · 운영과 CI

**① 목표**  
Docker 릴리즈, GitHub Actions 테스트, 로그와 백업을 체크리스트로 운영 루틴에 넣는다.

## ② 📖 이론

### 왜 쓰는지

내 컴퓨터의 `mix phx.server`는 도구와 소스와 DB 파일이 한곳에 섞여 있다. 운영은 컴파일 결과만 올리고, 올릴 때마다 같은 테스트가 먼저 돌아야 한다. 장애 뒤에는 요청 번호가 있는 로그와 DB 파일 사본이 있어야 글을 되돌릴 수 있다.

### 핵심 개념

- **멀티 스테이지**: `board/Dockerfile` 빌더는 Elixir로 `mix release`, 실행 이미지는 Debian에 릴리즈와 `/data`만 둔다.
- **CI**: `.github/workflows/ci.yml`. push와 pull_request마다 `mix test`.
- **로그**: Phoenix 요청 로그와 `error.requestId`. 요약 실패는 `Logger.warning`.
- **백업**: SQLite는 `/data/board.db` 파일 복사. Postgres로 바꾼 뒤에는 덤프 명령으로 바꾼다.

### 비유

Dockerfile은 도시락 통이고 CI는 도시락을 담기 전에 뚜껑을 열어 보는 사람이다. 백업은 어제 도시락을 냉동실에 넣어 두는 일이다.

## ③ 🛠️ 실기

### 이미지

실행 사용자는 `app`이다. `PHX_SERVER=true`, `PORT=4000`, `DATABASE_PATH=/data/board.db`. `SECRET_KEY_BASE`는 compose에 학습용 자리표시자만 있다. 공개 주소에 올리기 전에 `mix phx.gen.secret` 값으로 바꾼다.

```bash
docker compose build
docker compose up
```

### 자동 테스트

워크플로는 `hexpm/elixir:1.18.4-erlang-27.3.4.16-debian-bookworm-20260824-slim` 안에서 `build-essential`, `git`을 설치하고 `board` 디렉터리에서 `mix test`를 실행한다. 의존성 컴파일에 git과 make가 필요해서 그 패키지를 빼면 CI가 깨진다.

### 운영 체크리스트

- [ ] `GET /health`가 `{"status":"ok"}`다. `force_ssl`이 이 경로를 막지 않는다
- [ ] `SECRET_KEY_BASE`, `AI_API_KEY`가 이미지 레이어와 git에 없다
- [ ] 컨테이너 사용자가 root가 아니다
- [ ] DB 볼륨 `board-data`가 컨테이너를 지워도 남는다
- [ ] 가입 메일 어댑터가 개발 Local로 운영에 남지 않았다
- [ ] `AI_DRIVER` 기본은 `mock`이다. 모델을 붙일 때만 `ollama` 또는 `openai`
- [ ] CI가 이 커밋에서 초록색이다
- [ ] 백업 파일을 다른 폴더에 복사해 `sqlite3`로 글 한 건을 읽었다
- [ ] 로그에서 실패한 요청의 `request_id`를 JSON `requestId`와 맞췄다
- [ ] 업로드 10MB와 로그인 429가 운영 설정에서도 같은 코드다

### 로그를 보는 명령

```bash
docker compose logs -f board
```

개발기에서는 `iex -S mix phx.server` 출력의 `request_id=`를 본다.

### 백업

SQLite 학습 배포:

```bash
docker compose exec board cat /data/board.db > board-backup.db
```

복구는 서버를 멈춘 뒤 그 파일을 `/data/board.db`에 다시 넣는다. 서버가 켜진 채 파일을 덮어쓰면 잠금이 난다.

## ④ 🔗 연동 포인트

CI는 study9 테스트를 그대로 실행한다. 이미지는 study10 릴리즈와 study11의 `DATABASE_PATH`(또는 나중에 `DATABASE_URL`)를 환경 변수로 받는다. study18의 `AI_DRIVER`도 같은 compose `environment`에 둔다. 백업 파일에는 비밀번호 해시와 문서 본문이 있으므로 공개 저장소에 올리지 않는다.

## ⑤ 오류 노트

| 증상 | 원인 | 해결 |
| --- | --- | --- |
| CI에서 `make not found` | bcrypt 빌드 도구 없음 | 워크플로의 `build-essential` |
| CI에서 git 의존성 실패 | git 미설치 | 같은 단계에 `git` |
| 컨테이너가 바로 종료 | `SECRET_KEY_BASE` 없음 | compose environment에 넣는다 |
| `/health`가 리다이렉트 | HTTPS 강제에 포함됨 | `prod.exs`가 `/health`를 제외한다 |
| 백업이 0바이트 | 서버가 파일을 잠금 | 복사는 읽기, 복구만 중지 후 |

## ⑥ 직접 해보기

1. 체크리스트에서 로컬로 확인 가능한 항목(헬스, mock, 볼륨 이름)에 날짜를 적는다.
2. `docker compose logs`에서 요청 한 줄의 request id를 찾는다.
3. DB 파일을 복사한 경로를 적고, 그 파일을 커밋 대상에서 뺐는지 본다.

## ⑦ ☐ 체크리스트

- [ ] Dockerfile이 빌드와 실행을 나누고 root로 서버를 켜지 않는다
- [ ] GitHub Actions가 `mix test`를 실행한다
- [ ] 헬스, 비밀, 볼륨, 메일, AI 드라이버를 운영 목록으로 확인했다
- [ ] SQLite 백업과 복구 순서를 적었다
- [ ] 로그의 요청 번호와 API `requestId`를 대응했다

## ⑧ 다음 단계

서버가 반복해서 올라가면 [study17.md](study17.md)에서 새 글과 댓글을 다른 브라우저에 바로 반영한다.
