defmodule BoardWeb.FallbackController do
  use BoardWeb, :controller

  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    if Board.Accounts.email_taken?(changeset) do
      BoardWeb.ApiError.send(conn, 409, "EMAIL_TAKEN", "이미 가입된 이메일입니다.")
    else
      BoardWeb.ApiError.send(
        conn,
        400,
        "VALIDATION_ERROR",
        "입력값을 확인하세요.",
        BoardWeb.ApiError.fields(changeset)
      )
    end
  end

  def call(conn, {:error, :not_found}),
    do: BoardWeb.ApiError.send(conn, 404, "NOT_FOUND", "없는 자원입니다.")

  def call(conn, {:error, :forbidden}),
    do: BoardWeb.ApiError.send(conn, 403, "FORBIDDEN", "이 작업을 할 권한이 없습니다.")

  def call(conn, {:error, :unauthorized}),
    do: BoardWeb.ApiError.send(conn, 401, "UNAUTHORIZED", "로그인이 필요합니다.")

  def call(conn, {:error, :invalid_credentials}),
    do: BoardWeb.ApiError.send(conn, 401, "INVALID_CREDENTIALS", "이메일 또는 비밀번호가 올바르지 않습니다.")

  def call(conn, {:error, :bad_request}),
    do: BoardWeb.ApiError.send(conn, 400, "BAD_REQUEST", "요청을 해석할 수 없습니다.")

  def call(conn, {:error, :payload_too_large}),
    do: BoardWeb.ApiError.send(conn, 413, "PAYLOAD_TOO_LARGE", "업로드 한도를 초과했습니다.")

  def call(conn, {:error, :ai_unavailable}),
    do: BoardWeb.ApiError.send(conn, 502, "AI_UNAVAILABLE", "AI 응답을 가져오지 못했습니다.")
end
