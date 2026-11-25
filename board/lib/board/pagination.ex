defmodule Board.Pagination do
  @moduledoc """
  공통 API 스펙 v1의 page, limit, q, sort를 해석한다.
  page는 1부터, limit 기본 10, 상한 50.
  """

  defstruct page: 1, limit: 10, offset: 0, q: nil, sort: "-createdAt"

  def parse(params) when is_map(params) do
    page = params |> fetch("page") |> positive_or(1)
    limit = params |> fetch("limit") |> limit_or_default()

    %__MODULE__{
      page: page,
      limit: limit,
      offset: (page - 1) * limit,
      q: params |> fetch("q") |> blank_nil(),
      sort: params |> fetch("sort") |> allowed_sort()
    }
  end

  def meta(%__MODULE__{} = page, total) do
    total_pages = if total == 0, do: 0, else: div(total + page.limit - 1, page.limit)

    %{
      page: page.page,
      limit: page.limit,
      total: total,
      totalPages: total_pages,
      q: page.q
    }
  end

  defp fetch(params, key) do
    Map.get(params, key) || Map.get(params, String.to_existing_atom(key))
  end

  defp positive_or(nil, default), do: default

  defp positive_or(value, default) do
    case Integer.parse(to_string(value)) do
      {n, ""} when n >= 1 -> n
      _ -> default
    end
  end

  defp limit_or_default(nil), do: 10

  defp limit_or_default(value) do
    case Integer.parse(to_string(value)) do
      {n, ""} when n > 50 -> 50
      {n, ""} when n >= 1 -> n
      _ -> 10
    end
  end

  defp blank_nil(q) when is_binary(q) do
    trimmed = String.trim(q)
    if trimmed == "", do: nil, else: trimmed
  end

  defp blank_nil(_q), do: nil

  defp allowed_sort(sort) when sort in ["createdAt", "-createdAt", "-commentCount"], do: sort
  defp allowed_sort(_sort), do: "-createdAt"
end
