defmodule Board.Blog.Cache do
  @moduledoc """
  게시글 첫 페이지를 ETS에 15초 보관한다.
  테스트에서는 :cache_enabled 가 false라 항상 DB를 본다.
  """

  @table :board_cache
  @ttl 15

  def setup do
    if :ets.whereis(@table) == :undefined do
      :ets.new(@table, [:named_table, :public, read_concurrency: true])
    end

    :ok
  end

  def fetch(key, loader) when is_function(loader, 0) do
    if Application.get_env(:board, :cache_enabled, true) do
      now = System.system_time(:second)

      case :ets.lookup(@table, key) do
        [{^key, value, expires}] when expires > now ->
          value

        _other ->
          value = loader.()
          :ets.insert(@table, {key, value, now + @ttl})
          value
      end
    else
      loader.()
    end
  end

  def invalidate(key) do
    if :ets.whereis(@table) != :undefined, do: :ets.delete(@table, key)
    :ok
  end
end
