defmodule Board.AccountsTest do
  use Board.DataCase, async: false

  alias Board.Accounts

  test "register hashes the password and rejects a duplicate email" do
    attrs = %{"email" => "mina@example.com", "password" => "password123", "nickname" => "mina"}
    assert {:ok, user, token} = Accounts.register_user(attrs)
    assert user.password_hash
    refute user.password_hash == "password123"
    assert is_binary(token)
    assert {:error, changeset} = Accounts.register_user(attrs)
    assert Accounts.email_taken?(changeset)
  end

  test "authenticate hides which field was wrong" do
    {:ok, _user, _token} =
      Accounts.register_user(%{
        "email" => "mina@example.com",
        "password" => "password123",
        "nickname" => "mina"
      })

    assert {:ok, _user, token} = Accounts.authenticate("mina@example.com", "password123")
    assert Accounts.get_user_by_token(token)
    assert {:error, :invalid} = Accounts.authenticate("mina@example.com", "nope")
    assert {:error, :invalid} = Accounts.authenticate("missing@example.com", "password123")
  end
end
