defmodule Board.AI.Client do
  @moduledoc """
  AI_DRIVER=mock 이면 외부 모델 없이 짧은 답을 만든다.
  ollama 와 openai 는 환경 변수의 주소로 JSON을 보낸다.
  """

  require Logger

  def summarize(text) when is_binary(text) do
    complete(Board.AI.Prompt.summarize(text), fn ->
      compact = text |> String.replace(~r/\s+/u, " ") |> String.trim() |> String.slice(0, 80)
      "요약: #{compact}"
    end)
  end

  def complete(prompt, mock_fun) when is_binary(prompt) and is_function(mock_fun, 0) do
    case driver() do
      "mock" ->
        {:ok, mock_fun.()}

      "ollama" ->
        ollama(prompt)

      "openai" ->
        openai(prompt)

      other ->
        Logger.warning("unknown AI_DRIVER=#{other}")
        {:error, :unavailable}
    end
  end

  def stream_tokens(text) when is_binary(text) do
    case summarize(text) do
      {:ok, summary} -> {:ok, String.split(summary, ~r/\s+/u, trim: true)}
      {:error, reason} -> {:error, reason}
    end
  end

  def decode_ollama_line(line) when is_binary(line) do
    case Jason.decode(String.trim(line)) do
      {:ok, %{"response" => token, "done" => done}} when is_binary(token) and is_boolean(done) ->
        {:ok, token, done}

      _other ->
        :error
    end
  end

  defp ollama(prompt) do
    settings = settings()

    request(
      settings.url <> "/api/generate",
      %{model: settings.model, prompt: prompt, stream: false},
      nil,
      fn body -> body["response"] end
    )
  end

  defp openai(prompt) do
    settings = settings()

    request(
      String.trim_trailing(settings.url, "/") <> "/v1/chat/completions",
      %{model: settings.model, messages: [%{role: "user", content: prompt}], stream: false},
      settings.api_key,
      fn body ->
        body |> get_in(["choices", Access.at(0), "message", "content"])
      end
    )
  end

  defp request(url, payload, api_key, pick) do
    headers =
      if is_binary(api_key) and api_key != "" do
        [{"authorization", "Bearer " <> api_key}]
      else
        []
      end

    case Req.post(url, json: payload, headers: headers, receive_timeout: settings().timeout_ms) do
      {:ok, %{status: status, body: body}} when status in 200..299 ->
        case pick.(body) do
          text when is_binary(text) and text != "" -> {:ok, String.trim(text)}
          _other -> {:error, :unavailable}
        end

      {:ok, %{status: status}} ->
        Logger.warning("ai http status=#{status}")
        {:error, :unavailable}

      {:error, reason} ->
        Logger.warning("ai request failed: #{inspect(reason)}")
        {:error, :unavailable}
    end
  end

  defp driver, do: settings().driver

  defp settings do
    config = Application.get_env(:board, :ai, [])

    %{
      driver: config[:driver] || "mock",
      url: config[:url] || "http://127.0.0.1:11434",
      api_key: config[:api_key],
      model: config[:model] || "gemma4:12b",
      timeout_ms: config[:timeout_ms] || 30_000
    }
  end
end
