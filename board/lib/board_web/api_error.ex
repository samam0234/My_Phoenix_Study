defmodule BoardWeb.ApiError do
  import Plug.Conn
  import Phoenix.Controller, only: [json: 2]

  def send(conn, status, code, message, fields \\ nil) do
    error = %{
      code: code,
      message: message,
      requestId: conn.assigns[:request_id]
    }

    error = if is_map(fields), do: Map.put(error, :fields, fields), else: error
    conn |> put_status(status) |> json(%{error: error})
  end

  def fields(%Ecto.Changeset{} = changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _match, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
