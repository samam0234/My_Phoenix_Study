defmodule BoardWeb.PostChannel do
  use BoardWeb, :channel

  @impl true
  def join("posts:lobby", _payload, socket) do
    {:ok, socket}
  end

  def join("posts:" <> _rest, _payload, _socket) do
    {:error, %{reason: "unknown topic"}}
  end
end
