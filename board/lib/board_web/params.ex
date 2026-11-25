defmodule BoardWeb.Params do
  def id(value) do
    case Integer.parse(to_string(value)) do
      {number, ""} when number > 0 -> {:ok, number}
      _other -> :error
    end
  end
end
