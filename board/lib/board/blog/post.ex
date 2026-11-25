defmodule Board.Blog.Post do
  use Ecto.Schema
  import Ecto.Changeset

  schema "posts" do
    field :title, :string
    field :body, :string
    field :tags, {:array, :string}, default: []
    field :tags_text, :string, virtual: true
    field :comment_count, :integer, virtual: true, default: 0

    belongs_to :author, Board.Accounts.User
    has_many :comments, Board.Blog.Comment

    timestamps(type: :utc_datetime)
  end

  def changeset(post, attrs) do
    post
    |> cast(attrs, [:title, :body, :tags])
    |> validate_required([:title, :body], message: "필수입니다.")
    |> validate_length(:title, min: 1, max: 200, message: "1~200자로 입력하세요.")
    |> validate_length(:body, min: 1, max: 5000, message: "1~5000자로 입력하세요.")
    |> validate_tags()
  end

  defp validate_tags(changeset) do
    validate_change(changeset, :tags, fn :tags, tags ->
      cond do
        length(tags) > 5 ->
          [tags: {"태그는 5개 이하로 입력하세요.", []}]

        Enum.any?(tags, &(String.length(&1) > 30)) ->
          [tags: {"태그는 30자 이하로 입력하세요.", []}]

        true ->
          []
      end
    end)
  end
end
