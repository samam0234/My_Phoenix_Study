defmodule Board.Blog.Comment do
  use Ecto.Schema
  import Ecto.Changeset

  schema "comments" do
    field :body, :string
    belongs_to :post, Board.Blog.Post
    belongs_to :author, Board.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(comment, attrs) do
    comment
    |> cast(attrs, [:body])
    |> validate_required([:body], message: "필수입니다.")
    |> validate_length(:body, min: 1, max: 1000, message: "1~1000자로 입력하세요.")
  end
end
