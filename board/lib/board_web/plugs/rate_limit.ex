defmodule BoardWeb.Plugs.RateLimit do
  import Plug.Conn

  @table :board_rate

  def setup do
    if :ets.whereis(@table) == :undefined do
      :ets.new(@table, [:named_table, :public, write_concurrency: true])
    end

    :ok
  end

  def init(opts), do: opts

  def call(conn, opts) do
    if Application.get_env(:board, :rate_limit_enabled, true) do
      limit = Keyword.get(opts, :limit, 30)
      window = Keyword.get(opts, :window, 60)
      now = System.system_time(:second)
      bucket = div(now, window)
      key = {ip(conn), conn.request_path, bucket}
      :ets.delete(@table, {ip(conn), conn.request_path, bucket - 1})
      count = :ets.update_counter(@table, key, {2, 1}, {key, 0})

      if count > limit do
        conn
        |> put_resp_header("retry-after", Integer.to_string(window))
        |> BoardWeb.ApiError.send(429, "RATE_LIMITED", "호출 횟수가 너무 많습니다.")
        |> halt()
      else
        conn
      end
    else
      conn
    end
  end

  defp ip(conn) do
    conn.remote_ip |> :inet.ntoa() |> to_string()
  end
end
