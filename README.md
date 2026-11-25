# Phoenix 학습

Elixir로 만든 서버 프레임워크 Phoenix만 다루는 학습 저장소다. LiveView가 서버에 화면 상태를 두고, 바뀐 조각만 WebSocket으로 보낸다. 실행 환경은 Erlang VM(BEAM)이다.

## 문서

| 파일 | 내용 |
| --- | --- |
| [study0.md](study0.md) ~ [study10.md](study10.md) | 기초 |
| [studyMidpoint.md](studyMidpoint.md) | 게시판 + 로그인 |
| [study11.md](study11.md) ~ [study18.md](study18.md) | 심화 |
| [studyFinal.md](studyFinal.md) | 심화 응용 |

실습 코드는 [board/](board/) 안에 있다. Phoenix 1.8.17, Elixir 1.17 이상, 기본 데이터베이스는 SQLite다.

## 실행

Elixir와 Erlang이 설치되어 있으면:

```bash
cd board
mix setup
mix phx.server
```

브라우저에서 `http://localhost:4000` 을 연다. 시드 계정은 `mina@example.com` / `password123` 이다.

Elixir가 없으면 Docker로 테스트를 돌릴 수 있다.

```bash
docker run --rm -v "$PWD:/work" -w /work/board -p 4000:4000 hexpm/elixir:1.18.4-erlang-27.3.4.16-debian-bookworm-20260824-slim bash -lc "apt-get update && apt-get install -y build-essential git && mix local.hex --force && mix local.rebar --force && mix test"
```

이 환경에서 `mix test`는 19개 테스트가 통과했다.

## API

JSON API는 `/api/posts` 이다. 목록은 `{data, meta}`, 오류는 `{error: {code, message, fields, requestId}}` 다. 헬스 체크는 `/health`, 문서는 `/api-docs` 다.
