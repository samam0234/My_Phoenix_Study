# study10 · 배포와 기초 정리

**① 목표**  
릴리즈 이미지로 앱을 빌드하고, 도메인과 HTTPS가 요청에 무엇을 하는지 정리한 뒤 기초 구간을 한 표로 닫는다.

## ② 📖 이론

### 왜 쓰는지

`mix phx.server`는 개발기 도구가 함께 떠 있다. 운영은 컴파일된 릴리즈만 올리고, 코드 리로더와 개발 비밀은 빼야 한다. 도메인은 사람용 이름이고, HTTPS는 그 이름으로 오가는 내용을 암호화한다.

### 핵심 개념

- **assets.deploy**: CSS, JS를 압축하고 `phx.digest`로 지문 파일명을 만든다.
- **mix release**: `bin/board start`. `PHX_SERVER=true`일 때만 HTTP를 연다.
- **도메인**: `PHX_HOST`. 쿠키와 URL 생성의 호스트.
- **HTTPS**: `prod.exs`의 `force_ssl`. 앞단 프록시의 `x-forwarded-proto`를 보고 HTTP를 HTTPS로 돌린다. `/health`는 제외한다.
- **환경 변수**: `SECRET_KEY_BASE`, `DATABASE_PATH`, `PORT`, `CORS_ORIGIN`.

### 비유

개발 서버는 공사장 가건물이고 릴리즈는 문을 연 매장이다. 도메인은 간판, HTTPS는 매장과 손님 사이 호스에 자물쇠를 채우는 일이다. 자물쇠 열쇠(`SECRET_KEY_BASE`)를 저장소에 적어 두지 않는다.

## ③ 🛠️ 실기

`board/Dockerfile`은 빌더에서 의존성과 에셋을 컴파일하고 `mix release`를 만든 뒤, 실행 이미지에는 릴리즈와 `/data`만 남긴다. 루트 `docker-compose.yml`이 4000번 포트를 연다. `SECRET_KEY_BASE` 자리는 학습용 자리표시자다. 실제로 열기 전에 `mix phx.gen.secret`으로 바꾼다.

```bash
cd board
mix phx.gen.secret
```

compose의 환경 변수에 그 값을 넣는다.

```bash
docker compose build
docker compose up
```

헬스 확인:

```bash
curl http://localhost:4000/health
```

`{"status":"ok"}` 이면 프로세스가 요청을 받는다. 브라우저 확인은 `http://localhost:4000/posts`다.

### 줄별 설명 (Dockerfile 요지)

| 단계 | 설명 |
| --- | --- |
| `MIX_ENV=prod` | 개발 전용 의존성을 빼고 컴파일 |
| `mix deps.get --only prod` | 테스트 전용 패키지를 이미지에 넣지 않음 |
| `mix assets.deploy` | 압축 CSS/JS와 다이제스트 |
| `mix release` | ERTS가 들어 있는 실행 폴더 |
| 두 번째 `FROM` | 컴파일러가 없는 얇은 이미지 |
| `USER app` | root로 서버를 열지 않음 |
| `DATABASE_PATH=/data/board.db` | 볼륨에 DB 파일을 둔다 |
| `CMD bin/board start` | `PHX_SERVER=true`와 함께 HTTP를 연다 |

### 기초 구간 총정리

| 단계 | 남는 것 |
| --- | --- |
| study0 | Elixir, `mix phx.new`, Git, `.env` |
| study1 | 패턴 매칭, 파이프, HEEx 이스케이프, 라이브 리로드 |
| study2 | 컨텍스트, LiveView 생명주기, assign |
| study3 | 스키마, changeset, localStorage |
| study4 | 라우터, 쿼리, 404/400 |
| study5 | 폼 검증, 400 필드 오류, 중복 제출 방지 |
| study6 | SQLite CRUD, `data`/`meta`, 환경 변수 DB |
| study7 | 세션, 토큰, 해시, CORS, XSS, CSRF |
| study8 | 폴더, 공용 모듈, dev/prod 설정 |
| study9 | ExUnit, 샌드박스, mock, 로그 |

## ④ 🔗 연동 포인트

배포 환경의 `DATABASE_PATH`가 study6 Repo로 연결된다. `SECRET_KEY_BASE`가 세션 쿠키 서명에 쓰인다. `CORS_ORIGIN`이 브라우저 출처를 제한한다. `PHX_HOST`가 URL 생성 호스트다. 배포 뒤 점검표:

- [ ] `/health`가 200
- [ ] `/posts` HTML이 열린다
- [ ] 회원가입 후 글 작성, 새로고침 뒤에도 글이 남는다 (`/data` 볼륨)
- [ ] `/api/posts`의 `meta.total`이 글 수와 같다
- [ ] 잘못된 토큰이 401
- [ ] 로그에 스택이 응답 본문으로 나가지 않는다
- [ ] `SECRET_KEY_BASE`가 예시 문자열이 아니다

## ⑤ 오류 노트

| 증상 | 원인 | 해결 |
| --- | --- | --- |
| 컨테이너는 떴는데 브라우저가 거부 | 프로세스가 127.0.0.1만 염 | 엔드포인트 `ip`는 모든 인터페이스. 포트 매핑 `-p 4000:4000` |
| HTTPS로만 열리고 헬스체크 실패 | `force_ssl`이 `/health`까지 리다이렉트 | `paths: ["/health"]` 제외 |
| 재시작 후 글이 사라짐 | DB가 컨테이너 안에만 있음 | `/data` 볼륨과 `DATABASE_PATH` |
| `SECRET_KEY_BASE is missing` | 운영 환경 변수 없음 | `mix phx.gen.secret` 값을 주입 |

## ⑥ 직접 해보기

1. 로컬 `mix phx.server`와 `curl /health`를 비교한다.
2. `mix phx.gen.secret` 출력 길이를 확인하고 그 값을 파일에 커밋하지 않는다.
3. 기초 표에서 약한 단계 하나를 골라 해당 study의 체크리스트를 다시 표시한다.

## ⑦ ☐ 체크리스트

- [ ] `mix release` 또는 Docker 빌드 절차를 읽었다
- [ ] 도메인은 호스트 이름, HTTPS는 암호화와 강제 리다이렉트라는 점을 말했다
- [ ] 배포 환경 변수와 DB 경로를 점검표에 적었다
- [ ] 기초 10단계 표를 한 번 소리 내어 요약했다

## ⑧ 다음 단계

기초만으로 게시판과 로그인을 한 서비스로 묶는 글은 [studyMidpoint.md](studyMidpoint.md)다.
