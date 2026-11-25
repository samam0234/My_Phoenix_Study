defmodule Board.Documents.Question do
  use Ecto.Schema
  import Ecto.Changeset

  schema "questions" do
    field :question, :string
    field :answer, :string
    field :sources, {:array, :map}, default: []

    belongs_to :document, Board.Documents.Document

    timestamps(type: :utc_datetime)
  end

  def changeset(question, attrs) do
    question
    |> cast(attrs, [:question, :answer, :sources, :document_id])
    |> validate_required([:question, :answer, :document_id], message: "필수입니다.")
    |> validate_length(:question, min: 1, max: 1000, message: "1~1000자로 입력하세요.")
  end
end
