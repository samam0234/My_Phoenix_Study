defmodule Board.Repo.Migrations.CreateBoardTables do
  use Ecto.Migration

  def change do
    create table(:users) do
      add :email, :string, null: false
      add :nickname, :string, null: false
      add :password_hash, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:users, [:email])

    create table(:user_tokens) do
      add :token, :binary, null: false
      add :context, :string, null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create unique_index(:user_tokens, [:token])
    create index(:user_tokens, [:user_id])

    create table(:posts) do
      add :title, :string, null: false
      add :body, :text, null: false
      add :tags, {:array, :string}, null: false, default: []
      add :author_id, references(:users, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:posts, [:author_id])
    create index(:posts, [:inserted_at])

    create table(:comments) do
      add :body, :text, null: false
      add :post_id, references(:posts, on_delete: :delete_all), null: false
      add :author_id, references(:users, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:comments, [:post_id])

    create table(:documents) do
      add :filename, :string, null: false
      add :content_type, :string
      add :byte_size, :integer
      add :original_text, :text, null: false
      add :summary, :text
      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:documents, [:user_id])

    create table(:questions) do
      add :question, :text, null: false
      add :answer, :text, null: false
      add :sources, {:array, :map}, null: false, default: []
      add :document_id, references(:documents, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:questions, [:document_id])
  end
end
