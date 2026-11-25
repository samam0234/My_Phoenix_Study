defmodule Board.Accounts.UserNotifier do
  import Swoosh.Email
  require Logger

  def deliver_welcome(%Board.Accounts.User{} = user) do
    email =
      new()
      |> to(user.email)
      |> from({"Board", "board@localhost"})
      |> subject("가입을 환영합니다")
      |> text_body("안녕하세요 #{user.nickname}님. Phoenix 게시판에 가입했습니다.")

    case Board.Mailer.deliver(email) do
      {:ok, _metadata} ->
        {:ok, email}

      {:error, reason} ->
        Logger.warning("welcome mail failed: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
