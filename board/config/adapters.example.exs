# SQLite가 기본이다. 아래는 어댑터를 바꿀 때 참고하는 예시다.
# 이 파일은 컴파일되지 않는다.

# PostgreSQL
# mix.exs: {:postgrex, ">= 0.0.0"}
# lib/board/repo.ex adapter: Ecto.Adapters.Postgres
# config :board, Board.Repo,
#   url: System.get_env("DATABASE_URL"),
#   pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10")

# MariaDB / MySQL
# mix.exs: {:myxql, ">= 0.0.0"}
# adapter: Ecto.Adapters.MyXQL
# config :board, Board.Repo,
#   username: System.get_env("DB_USERNAME"),
#   password: System.get_env("DB_PASSWORD"),
#   hostname: System.get_env("DB_HOST"),
#   database: System.get_env("DB_NAME") || "board",
#   port: String.to_integer(System.get_env("DB_PORT") || "3306")

# MongoDB는 Ecto Repo 어댑터가 아니다.
# mix.exs: {:mongodb_driver, "~> 1.5"}
# 컬렉션 접근은 Mongo.start_link(url: System.get_env("MONGODB_URL")) 로 따로 둔다.
# 게시글 스키마의 changeset 검증은 Ecto에 남기고, 저장만 Mongo 모듈로 바꿀 수 있다.
