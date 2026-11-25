# study0 · 환경 설정

**① 목표**  
Elixir, Erlang, Phoenix 생성기를 설치하고 `board` 프로젝트를 띄운 뒤 Git과 `.env`까지 준비한다.

## ② 📖 이론

### 왜 쓰는지

Phoenix 코드는 Elixir로 쓰고, Elixir는 Erlang VM 위에서 돌아간다. 생성기 `mix phx.new`가 폴더, 설정, 개발 서버, 데이터베이스 자리를 한 번에 만든다. 버전을 맞추지 않으면 의존성 컴파일이 바로 멈춘다.

### 핵심 개념

- **Elixir**: 우리가 쓰는 언어. 이 저장소는 `~> 1.17` 이다.
- **Erlang/OTP**: 가상 머신. Phoenix 1.8은 OTP 25 이상을 요구한다. 실습 이미지는 OTP 27이다.
- **Mix**: 빌드 도구. `mix deps.get`, `mix test`, `mix phx.server`를 실행한다.
- **Hex**: 패키지 저장소. `phoenix` 1.8.17을 받아 온다.
- **phx_new**: `mix phx.new` 명령을 설치하는 아카이브.

### 비유

Erlang VM은 건물, Elixir는 그 건물의 작업 언어, Phoenix는 이미 배관이 들어간 방 구조, Mix는 공구 상자다. `mix phx.new board`는 그 공구로 `board`라는 방 이름을 붙이는 일이다.

## ③ 🛠️ 실기

### 버전 확인과 설치

Windows는 [Elixir 설치 안내](https://elixir-lang.org/install.html)로 Elixir를 설치하면 Erlang이 함께 붙는 경우가 많다. 설치 뒤 터미널에서 확인한다.

```bash
elixir -v
mix --version
```

기대하는 출력의 형태는 다음과 같다.

```text
Erlang/OTP 27 [erts-15.x]
Elixir 1.18.x
```

생성기를 설치하고 SQLite 프로젝트를 만든다.

```bash
mix local.hex --force
mix local.rebar --force
mix archive.install hex phx_new 1.8.17
mix phx.new board --database sqlite3
cd board
mix ecto.create
mix phx.server
```

브라우저에서 `http://localhost:4000` 을 연다. 이 저장소에는 이미 생성된 `board/`가 있으므로, 클론한 뒤에는 `cd board && mix setup && mix phx.server` 만 하면 된다.

### 폴더 구조

```text
board/
  mix.exs              # 앱 이름, Elixir 버전, 의존성
  config/              # config.exs, dev.exs, test.exs, prod.exs, runtime.exs
  lib/board/           # 계정, 게시글, 문서, AI (도메인)
  lib/board_web/       # 라우터, 컨트롤러, LiveView, 채널
  priv/repo/migrations # 테이블 생성
  assets/              # Tailwind, esbuild, JS 훅
  test/                # ExUnit
```

### 줄별 설명 (`board/mix.exs` 핵심)

| 줄 | 코드 | 설명 |
| --- | --- | --- |
| 1 | `defmodule Board.MixProject` | Mix가 읽는 프로젝트 모듈 이름 |
| 2 | `use Mix.Project` | `project/0`, `application/0` 규칙을 가져온다 |
| 4 | `app: :board` | OTP 애플리케이션 이름. 모듈 `Board`와 쌍이다 |
| 6 | `elixir: "~> 1.17"` | 1.17 이상, 2.0 미만 |
| 7 | `elixirc_paths` | 테스트에서만 `test/support`를 컴파일한다 |
| 43 | `{:phoenix, "~> 1.8.17"}` | 프레임워크 본체 |
| 46 | `{:ecto_sqlite3, ">= 0.0.0"}` | 파일 데이터베이스. 별도 DB 서버가 필요 없다 |
| 49 | `{:phoenix_live_view, "~> 1.2.0"}` | 서버 상태 화면 |
| 75 | `{:bcrypt_elixir, "~> 3.2"}` | 비밀번호 해시. study7에서 쓴다 |
| 76 | `{:bandit, "~> 1.5"}` | HTTP 서버 |
| 88 | `setup:` | 의존성, DB, 에셋을 한 번에 준비하는 별칭 |

### Git과 .gitignore

저장소 루트가 이 학습 폴더다. `board/.gitignore`는 컴파일 결과와 비밀, DB 파일을 제외한다.

```text
/_build/
/deps/
*.db
*.db-*
.env
/priv/uploads/*
```

| 줄 | 의미 |
| --- | --- |
| `/_build/` | 컴파일된 빔 파일. 다시 만들 수 있다 |
| `/deps/` | Hex에서 받은 라이브러리 |
| `*.db` | SQLite 파일. 사람마다 내용이 다르다 |
| `.env` | 로컬 비밀. `.env.example`만 커밋한다 |

### 환경 변수 파일

`board/.env.example`을 `board/.env`로 복사한다. `config/runtime.exs`는 **개발 환경에서만** 이 파일을 읽고, 이미 설정된 변수는 덮어쓰지 않는다.

```text
PORT=4000
CORS_ORIGIN=http://localhost:5173
AI_DRIVER=mock
AI_API_URL=http://127.0.0.1:11434
AI_MODEL=gemma4:12b
```

### 에디터 확장

- ElixirLS: 정의 이동, 경고, 포맷
- HEEx: `~H` 템플릿의 문법 색

VS Code 또는 Cursor에서 ElixirLS를 설치한 뒤 `board` 폴더를 연다.

## ④ 🔗 연동 포인트

Git 저장소는 `https://github.com/samam0234/My_Phoenix_Study` 이다. `.env`의 `DATABASE_PATH`는 운영에서 SQLite 파일 위치이고, `SECRET_KEY_BASE`는 `mix phx.gen.secret`으로 만든 값을 넣는다. 개발 기본 DB 경로는 `config/dev.exs`의 `board_dev.db`다. 이 파일이 있어야 study6의 마이그레이션이 테이블을 만든다.

## ⑤ 오류 노트

| 증상 | 원인 | 해결 |
| --- | --- | --- |
| `mix`를 찾을 수 없음 | Elixir가 PATH에 없음 | 설치 프로그램을 다시 실행하고 터미널을 새로 연다 |
| `phx.new`가 없음 | 아카이브 미설치 | `mix archive.install hex phx_new 1.8.17` |
| `(Mix) "make" not found` | bcrypt NIF 컴파일에 C 컴파일러 필요 | Windows는 Visual C++ 빌드 도구, Linux는 `build-essential` |
| 포트 4000 사용 중 | 이전 서버가 살아 있음 | 프로세스를 끄거나 `PORT=4001 mix phx.server` |
| `database is locked` | SQLite 파일을 여러 프로세스가 동시에 염 | 서버를 하나 두고, 테스트 중에는 개발 서버를 끈다 |

## ⑥ 직접 해보기

1. `elixir -v` 출력에 OTP 25 이상, Elixir 1.17 이상이 보이는지 적는다.
2. `board/.env.example`을 `.env`로 복사한 뒤 `AI_DRIVER`만 `mock`으로 두고 서버를 다시 시작한다.
3. `.gitignore` 때문에 `board_dev.db`가 `git status`에 안 나오는 것을 확인한다.

## ⑦ ☐ 체크리스트

- [ ] `elixir -v`로 Elixir 1.17+와 Erlang OTP 25+를 확인했다
- [ ] `mix archive.install hex phx_new`로 생성기를 설치했다
- [ ] 📌 노션 원문: Elixir와 Erlang 설치, `mix phx.new board`로 프로젝트 생성
- [ ] `mix phx.server`로 `http://localhost:4000`이 열린다
- [ ] 폴더가 `lib/board`, `lib/board_web`, `config`, `priv`, `assets`, `test`로 나뉜다
- [ ] ElixirLS와 HEEx 확장을 설치했다
- [ ] Git 저장소와 `board/.gitignore`로 `_build`, `deps`, `*.db`, `.env`를 제외했다
- [ ] `.env.example`을 `.env`로 복사해 환경 변수를 둘 자리를 만들었다

## ⑧ 다음 단계

서버가 뜨면 [study1.md](study1.md)에서 첫 화면과 패턴 매칭, 파이프를 확인한다.
