defmodule Board.Documents.Document do
  use Ecto.Schema
  import Ecto.Changeset

  schema "documents" do
    field :filename, :string
    field :content_type, :string
    field :byte_size, :integer
    field :original_text, :string
    field :summary, :string

    belongs_to :user, Board.Accounts.User
    has_many :questions, Board.Documents.Question

    timestamps(type: :utc_datetime)
  end

  def changeset(document, attrs) do
    document
    |> cast(attrs, [:filename, :content_type, :byte_size, :original_text, :summary, :user_id])
    |> validate_required([:filename, :original_text, :user_id], message: "필수입니다.")
    |> validate_length(:filename, min: 1, max: 200, message: "1~200자로 입력하세요.")
    |> validate_length(:original_text, min: 1, max: 200_000, message: "본문이 비었거나 너무 깁니다.")
  end
end
