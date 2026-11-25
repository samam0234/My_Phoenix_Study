defmodule BoardWeb.ErrorJSON do
  def render("400.json", assigns), do: error("BAD_REQUEST", "요청을 해석할 수 없습니다.", assigns)
  def render("401.json", assigns), do: error("UNAUTHORIZED", "로그인이 필요합니다.", assigns)
  def render("403.json", assigns), do: error("FORBIDDEN", "이 작업을 할 권한이 없습니다.", assigns)
  def render("404.json", assigns), do: error("NOT_FOUND", "없는 자원이거나 없는 경로입니다.", assigns)
  def render("413.json", assigns), do: error("PAYLOAD_TOO_LARGE", "업로드 한도를 초과했습니다.", assigns)
  def render("429.json", assigns), do: error("RATE_LIMITED", "호출 횟수가 너무 많습니다.", assigns)
  def render("500.json", assigns), do: error("INTERNAL", "서버 오류가 발생했습니다.", assigns)

  def render(template, assigns) do
    message = Phoenix.Controller.status_message_from_template(template)
    error("INTERNAL", message, assigns)
  end

  defp error(code, message, assigns) do
    request_id =
      case assigns do
        %{conn: conn} -> conn.assigns[:request_id]
        _other -> nil
      end

    %{error: %{code: code, message: message, requestId: request_id}}
  end
end
