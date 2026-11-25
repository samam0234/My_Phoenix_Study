defmodule Board.Accounts do
  @moduledoc """
  회원가입, 비밀번호 확인, API 토큰.
  브라우저 세션의 user_id와 API 토큰은 같은 users 테이블을 본다.
  """

  import Ecto.Query
  alias Board.Accounts.{User, UserNotifier, UserToken}
  alias Board.Repo

  def get_user(id) when is_integer(id), do: Repo.get(User, id)
  def get_user(_id), do: nil

  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: String.downcase(String.trim(email)))
  end

  def change_registration(%User{} = user \\ %User{}, attrs \\ %{}) do
    User.form_changeset(user, attrs)
  end

  def register_user(attrs) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, user} ->
        _ = UserNotifier.deliver_welcome(user)
        {:ok, token} = create_token(user)
        {:ok, user, token}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def verify_password(email, password) when is_binary(email) and is_binary(password) do
    user = get_user_by_email(email)

    cond do
      user && Bcrypt.verify_pass(password, user.password_hash) ->
        {:ok, user}

      user ->
        {:error, :invalid}

      true ->
        Bcrypt.no_user_verify()
        {:error, :invalid}
    end
  end

  def verify_password(_email, _password), do: {:error, :invalid}

  def authenticate(email, password) do
    case verify_password(email, password) do
      {:ok, user} ->
        {:ok, token} = create_token(user)
        {:ok, user, token}

      {:error, :invalid} ->
        {:error, :invalid}
    end
  end

  def create_token(%User{} = user) do
    raw = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)

    %UserToken{}
    |> Ecto.Changeset.change(%{token: hash(raw), context: "api", user_id: user.id})
    |> Repo.insert!()

    {:ok, raw}
  end

  def get_user_by_token(raw) when is_binary(raw) and raw != "" do
    hashed = hash(raw)

    Repo.one(
      from t in UserToken,
        where: t.token == ^hashed and t.context == "api",
        where: t.inserted_at > ago(7, "day"),
        join: u in assoc(t, :user),
        select: u
    )
  end

  def get_user_by_token(_raw), do: nil

  def delete_token(raw) when is_binary(raw) do
    hashed = hash(raw)
    Repo.delete_all(from t in UserToken, where: t.token == ^hashed and t.context == "api")
    :ok
  end

  def email_taken?(%Ecto.Changeset{errors: errors}) do
    Enum.any?(errors, fn
      {:email, {_message, meta}} -> meta[:constraint] == :unique
      _other -> false
    end)
  end

  defp hash(raw), do: :crypto.hash(:sha256, raw)
end
