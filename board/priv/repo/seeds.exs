alias Board.Accounts
alias Board.Blog

email = "mina@example.com"

user =
  case Accounts.get_user_by_email(email) do
    nil ->
      {:ok, user, _token} =
        Accounts.register_user(%{
          "email" => email,
          "password" => "password123",
          "nickname" => "mina"
        })

      user

    user ->
      user
  end

unless Blog.list_posts(%{}) |> elem(1) |> Map.get(:total) > 0 do
  {:ok, _post} =
    Blog.create_post(user, %{
      "title" => "첫 글",
      "body" => "안녕하세요",
      "tags" => ["intro"]
    })
end
