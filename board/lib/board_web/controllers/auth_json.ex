defmodule BoardWeb.AuthJSON do
  def auth(%{user: user, token: token}) do
    %{data: %{user: user_data(user), accessToken: token}}
  end

  def me(%{user: user}) do
    %{data: user_data(user)}
  end

  defp user_data(user) do
    %{id: user.id, email: user.email, nickname: user.nickname}
  end
end
