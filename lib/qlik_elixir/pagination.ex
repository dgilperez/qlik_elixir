defmodule QlikElixir.Pagination do
  @moduledoc """
  Helpers for cursor-based pagination used by Qlik Cloud APIs.

  Qlik APIs use cursor-based pagination with `next` and `prev` tokens
  in the response links.
  """

  @type cursor :: String.t() | nil

  @type paginated_response :: %{
          data: list(map()),
          next_cursor: cursor(),
          prev_cursor: cursor(),
          has_more: boolean(),
          total: non_neg_integer() | nil
        }

  @doc """
  Builds a query string from pagination options.

  ## Options

    * `:limit` - Maximum items per page
    * `:offset` - Number of items to skip (offset-based)
    * `:next` - Cursor for next page (cursor-based)
    * `:prev` - Cursor for previous page (cursor-based)

  ## Examples

      iex> QlikElixir.Pagination.build_query(limit: 50)
      "limit=50"

      iex> QlikElixir.Pagination.build_query(limit: 50, next: "abc123")
      "limit=50&next=abc123"

  """
  @spec build_query(keyword()) :: String.t()
  def build_query(opts) do
    opts
    |> Enum.filter(fn {_k, v} -> not is_nil(v) end)
    |> Enum.map(fn {k, v} -> "#{k}=#{URI.encode_www_form(to_string(v))}" end)
    |> Enum.join("&")
  end

  @doc """
  Parses a paginated API response into a structured format.

  Extracts data, pagination cursors, and metadata from the response.

  ## Examples

      iex> response = %{"data" => [%{"id" => "1"}], "links" => %{"next" => %{"href" => "/api?next=abc"}}}
      iex> QlikElixir.Pagination.parse_response(response)
      %{data: [%{"id" => "1"}], next_cursor: "abc", prev_cursor: nil, has_more: true, total: nil}

  """
  @spec parse_response(map()) :: paginated_response()
  def parse_response(response) do
    links = Map.get(response, "links", %{})
    next_href = get_in(links, ["next", "href"])
    prev_href = get_in(links, ["prev", "href"])

    next_cursor = extract_cursor(next_href, "next")
    prev_cursor = extract_cursor(prev_href, "prev")

    %{
      data: Map.get(response, "data", []),
      next_cursor: next_cursor,
      prev_cursor: prev_cursor,
      has_more: not is_nil(next_cursor),
      total: Map.get(response, "total")
    }
  end

  @doc """
  Extracts a cursor value from a URL query string.

  ## Examples

      iex> QlikElixir.Pagination.extract_cursor("/api?next=abc123", "next")
      "abc123"

      iex> QlikElixir.Pagination.extract_cursor("/api?limit=50", "next")
      nil

  """
  @spec extract_cursor(String.t() | nil, String.t()) :: cursor()
  def extract_cursor(nil, _param), do: nil

  def extract_cursor(url, param) do
    case URI.parse(url) do
      %URI{query: query} when is_binary(query) ->
        query
        |> URI.decode_query()
        |> Map.get(param)

      _ ->
        nil
    end
  end
end
