defmodule BoardWeb.UserSocket do
  use Phoenix.Socket

  channel "posts:*", BoardWeb.PostChannel

  @impl true
  def connect(_params, socket, _connect_info), do: {:ok, socket}

  @impl true
  def id(_socket), do: nil
end
