defmodule Board.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field :email, :string
    field :nickname, :string
    field :password, :string, virtual: true, redact: true
    field :password_hash, :string, redact: true

    has_many :posts, Board.Blog.Post, foreign_key: :author_id
    has_many :tokens, Board.Accounts.UserToken

    timestamps(type: :utc_datetime)
  end

  def form_changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :nickname, :password])
    |> validate_required([:email, :nickname, :password], message: "필수입니다.")
    |> update_change(:email, &String.downcase/1)
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "이메일 형식이 아닙니다.")
    |> validate_length(:nickname, min: 1, max: 30, message: "1~30자로 입력하세요.")
    |> validate_length(:password, min: 8, max: 72, message: "8자 이상으로 입력하세요.")
  end

  def registration_changeset(user, attrs) do
    user
    |> form_changeset(attrs)
    |> unique_constraint(:email, message: "이미 사용 중입니다.")
    |> hash_password()
  end

  defp hash_password(changeset) do
    if changeset.valid? && get_change(changeset, :password) do
      hash = Bcrypt.hash_pwd_salt(get_change(changeset, :password))

      changeset
      |> put_change(:password_hash, hash)
      |> delete_change(:password)
    else
      changeset
    end
  end
end
