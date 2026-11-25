# study11 · DB 확장

**① 목표**  
기본 SQLite를 유지한 채 PostgreSQL, MariaDB, MongoDB로 바꿀 때 어댑터와 설정이 어디서 달라지는지 Phoenix 안에서 정리한다.

## ② 📖 이론

### 왜 쓰는지

학습은 파일 DB로 충분하다. 운영에서 여러 앱 서버가 같은 데이터를 보려면 PostgreSQL 같은 서버형 DB가 필요하다. 어댑터를 바꾸면 마이그레이션 SQL 일부가 달라지므로, 스키마는 그대로 두고 연결만 갈아끼우는 경계를 알아 둔다.

### 핵심 개념

- **Ecto 어댑터**: `Ecto.Adapters.SQLite3`, `Postgres`, `MyXQL`.
- **Repo 모듈**: `use Ecto.Repo, otp_app: :board, adapter: ...`. 어댑터는 컴파일에 들어간다.
- **URL**: Postgres는 `DATABASE_URL=ecto://USER:PASS@HOST/board`.
- **MongoDB**: Ecto Repo 어댑터가 아니다. 드라이버로 컬렉션을 따로 연다. changeset 검증은 Ecto에 남겨 둘 수 있다.

### 비유

Repo는 콘센트 모양이고 어댑터는 플러그 변환기다. 책상(스키마)은 그대로 두고 벽 콘센트(DB 제품)만 바꾼다. MongoDB는 콘센트가 아니라 서랍장이라 변환기로 꽂히지 않고 서랍 모듈을 따로 둔다.

## ③ 🛠️ 실기

예시는 컴파일되지 않는 `board/config/adapters.example.exs`에 있다. 기본 앱은 SQLite다.

### PostgreSQL

`mix.exs`에 `{:postgrex, ">= 0.0.0"}`를 넣고 `Board.Repo`의 adapter를 `Ecto.Adapters.Postgres`로 바꾼 뒤:

```elixir
config :board, Board.Repo,
  url: System.get_env("DATABASE_URL"),
  pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10")
```

`DATABASE_URL`은 환경 변수다. 값은 커밋하지 않는다. 마이그레이션의 `references`와 `timestamps`는 그대로 돈다. 배열 컬럼 `tags`는 Postgres에서 진짜 배열이 되고, SQLite에서는 JSON 문자열이다. Ecto가 둘 다 리스트로 보여 준다.

그룹 쿼리는 이미 서브쿼리 `count`라 Postgres의 `ONLY_FULL_GROUP_BY`에도 컬럼을 전부 `GROUP BY`할 필요가 없다.

### MariaDB / MySQL

의존성은 `myxql`, 어댑터는 `Ecto.Adapters.MyXQL`이다.

```elixir
config :board, Board.Repo,
  username: System.get_env("DB_USERNAME"),
  password: System.get_env("DB_PASSWORD"),
  hostname: System.get_env("DB_HOST"),
  database: System.get_env("DB_NAME") || "board",
  port: String.to_integer(System.get_env("DB_PORT") || "3306")
```

`{:array, :string}`은 MySQL에서 JSON으로 저장되는 점을 마이그레이션 로그로 확인한다. 문자열 대소문자 검색은 `LIKE` 콜레이션에 따라 달라질 수 있어, 인덱스를 추가하기 전에 `mix ecto.migrate`로 빈 DB에 스키마를 먼저 만든다.

### MongoDB

```elixir
{:mongodb_driver, "~> 1.5"}
```

`Mongo.start_link(url: System.get_env("MONGODB_URL"), name: :board_mongo)`를 애플리케이션 자식으로 추가한다. 게시글 저장 함수만 `Mongo.insert_one(:board_mongo, "posts", doc)`으로 바꾸는 실험을 할 수 있다. 그때는 `Board.Blog`의 검증(changeset)과 저장을 함수로 나누고, 기본 경로는 계속 Repo를 쓴다. 이 저장소의 테스트는 SQLite를 유지한다.

### 줄별 설명

| 줄 | 설명 |
| --- | --- |
| adapter 옵션 | 컴파일 타임. 실행 중에만 URL을 바꿔서는 제품이 안 바뀐다 |
| `url:` | 사용자, 비밀번호, 호스트를 한 환경 변수로 |
| `pool_size` | 동시 연결 수. SQLite 학습 설정은 작게, 서버 DB는 10 전후에서 시작한다 |
| 배열 타입 | 제품마다 물리 저장이 달라도 스키마 필드는 `{:array, :string}` |
| Mongo 분리 | Ecto 마이그레이션을 Mongo에 그대로 실행하지 않는다 |

## ④ 🔗 연동 포인트

study6의 `DATABASE_PATH`는 SQLite 전용이다. Postgres로 바꾸면 그 변수 대신 `DATABASE_URL`을 `runtime.exs` 운영 블록에 연결하고, study10 컨테이너에 DB 서비스를 추가한다. study16의 백업은 파일 복사에서 `pg_dump`로 바뀐다. API의 `data` 모양은 DB 제품과 무관하게 유지한다.

## ⑤ 오류 노트

| 증상 | 원인 | 해결 |
| --- | --- | --- |
| `adapter not found` | 의존성을 안 넣고 use만 바꿈 | postgrex 또는 myxql을 deps에 추가하고 컴파일 |
| 비밀번호가 로그에 찍힘 | URL을 `IO.inspect` | 환경 변수만 읽고 로그에는 호스트만 |
| SQLite 테스트를 Postgres로 오해 | `test.exs`는 여전히 파일 DB | 테스트 설정은 일부러 SQLite 샌드박스로 둔다 |
| Mongo에 migrate | Ecto 마이그레이션을 그대로 실행 | Mongo 실험은 insert 함수로 한정 |

## ⑥ 직접 해보기

1. `adapters.example.exs`를 읽고 지금 `Board.Repo`의 adapter 한 줄을 찾는다.
2. 배열 필드 `tags`가 스키마와 마이그레이션 어디에 있는지 표시한다.
3. Postgres로 바꿀 때 지워야 할 환경 변수(`DATABASE_PATH`)와 새로 넣을 변수(`DATABASE_URL`)를 적는다.

## ⑦ ☐ 체크리스트

- [ ] SQLite, PostgreSQL, MariaDB의 어댑터 이름을 적었다
- [ ] 어댑터가 컴파일 타임이라는 점을 설명했다
- [ ] 접속 정보가 환경 변수다
- [ ] MongoDB는 Repo 교체가 아니라 별도 드라이버라는 점을 적었다

## ⑧ 다음 단계

데이터 저장소 다음으로 화면 쪽 라이브러리를 붙이는 글이 [study12.md](study12.md)다.
