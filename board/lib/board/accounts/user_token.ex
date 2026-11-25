defmodule Board.Accounts.UserToken do
  use Ecto.Schema

  schema "user_tokens" do
    field :token, :binary, redact: true
    field :context, :string
    belongs_to :user, Board.Accounts.User

    timestamps(type: :utc_datetime, updated_at: false)
  end
end
