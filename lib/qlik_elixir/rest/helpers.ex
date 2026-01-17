defmodule QlikElixir.REST.Helpers do
  @moduledoc """
  Shared helper functions for REST API modules.

  Provides common utilities for configuration handling, query building,
  and request body construction used across all REST endpoints.
  """

  alias QlikElixir.{Config, Error, Pagination}

  @doc """
  Extracts configuration from options, falling back to default config.

  ## Examples

      iex> QlikElixir.REST.Helpers.get_config([])
      %QlikElixir.Config{...}

      iex> config = QlikElixir.Config.new(api_key: "key", tenant_url: "https://example.com")
      iex> QlikElixir.REST.Helpers.get_config(config: config)
      %QlikElixir.Config{api_key: "key", ...}

  """
  @spec get_config(keyword()) :: Config.t()
  def get_config(opts) do
    case Keyword.get(opts, :config) do
      %Config{} = config -> config
      nil -> Config.new()
    end
  end

  @doc """
  Adds a parameter to a keyword list if the value is not nil.

  ## Examples

      iex> QlikElixir.REST.Helpers.add_param([], :limit, 10)
      [limit: 10]

      iex> QlikElixir.REST.Helpers.add_param([], :limit, nil)
      []

  """
  @spec add_param(keyword(), atom(), any()) :: keyword()
  def add_param(params, _key, nil), do: params
  def add_param(params, key, value), do: Keyword.put(params, key, value)

  @doc """
  Puts a key-value pair into a map if the value is not nil.

  ## Examples

      iex> QlikElixir.REST.Helpers.put_if_present(%{}, "name", "test")
      %{"name" => "test"}

      iex> QlikElixir.REST.Helpers.put_if_present(%{}, "name", nil)
      %{}

  """
  @spec put_if_present(map(), String.t(), any()) :: map()
  def put_if_present(map, _key, nil), do: map
  def put_if_present(map, key, value), do: Map.put(map, key, value)

  @doc """
  Builds a query string from options using common pagination parameters.

  Takes a list of `{api_key, opts_key}` tuples to map option keys to API query params,
  plus standard pagination params (limit, next).

  ## Examples

      iex> QlikElixir.REST.Helpers.build_query([limit: 10, space_id: "abc"], [{:spaceId, :space_id}])
      "limit=10&spaceId=abc"

  """
  @spec build_query(keyword(), list({atom(), atom()})) :: String.t()
  def build_query(opts, param_mappings) do
    params =
      []
      |> add_param(:limit, Keyword.get(opts, :limit))
      |> add_param(:next, Keyword.get(opts, :next))

    params =
      Enum.reduce(param_mappings, params, fn {api_key, opts_key}, acc ->
        add_param(acc, api_key, Keyword.get(opts, opts_key))
      end)

    Pagination.build_query(params)
  end

  @doc """
  Builds the full path with query string appended if present.

  ## Examples

      iex> QlikElixir.REST.Helpers.build_path("api/v1/apps", "limit=10")
      "api/v1/apps?limit=10"

      iex> QlikElixir.REST.Helpers.build_path("api/v1/apps", "")
      "api/v1/apps"

  """
  @spec build_path(String.t(), String.t()) :: String.t()
  def build_path(base_path, ""), do: base_path
  def build_path(base_path, query), do: "#{base_path}?#{query}"

  @doc """
  Builds a request body map from params using provided field list.

  Supports two formats:
  - Atom list: `[:name, :description]` - uses atom as both param key and API key
  - Tuple list: `[{"apiKey", :param_key}]` - maps param key to different API key

  ## Examples

      iex> params = %{name: "Test", description: "Desc"}
      iex> QlikElixir.REST.Helpers.build_body(params, [:name, :description])
      %{"name" => "Test", "description" => "Desc"}

      iex> params = %{space_id: "abc"}
      iex> QlikElixir.REST.Helpers.build_body(params, [{"spaceId", :space_id}])
      %{"spaceId" => "abc"}

  """
  @spec build_body(map(), list(atom() | {String.t(), atom()})) :: map()
  def build_body(params, field_keys) do
    Enum.reduce(field_keys, %{}, fn field_spec, acc ->
      {api_key, param_key} = normalize_field_spec(field_spec)

      value =
        case Map.fetch(params, param_key) do
          {:ok, v} -> v
          :error -> Map.get(params, to_string(param_key))
        end

      put_if_present(acc, api_key, value)
    end)
  end

  defp normalize_field_spec({api_key, param_key}) when is_binary(api_key) and is_atom(param_key) do
    {api_key, param_key}
  end

  defp normalize_field_spec(key) when is_atom(key) do
    {to_string(key), key}
  end

  @doc """
  Normalizes a delete response to `:ok` on success.

  Converts `:file_not_found` errors to `:not_found` with a custom message.

  ## Examples

      iex> QlikElixir.REST.Helpers.normalize_delete_response({:ok, %{}}, "User")
      :ok

      iex> QlikElixir.REST.Helpers.normalize_delete_response({:error, %Error{type: :file_not_found}}, "User")
      {:error, %Error{type: :not_found, message: "User not found"}}

  """
  @spec normalize_delete_response({:ok, any()} | {:error, any()}, String.t()) :: :ok | {:error, any()}
  def normalize_delete_response({:ok, _}, _resource_name), do: :ok

  def normalize_delete_response({:error, %Error{type: :file_not_found}}, resource_name) do
    {:error, %Error{type: :not_found, message: "#{resource_name} not found"}}
  end

  def normalize_delete_response(error, _resource_name), do: error

  @doc """
  Normalizes a get response, converting `:file_not_found` to `:not_found`.

  ## Examples

      iex> QlikElixir.REST.Helpers.normalize_get_response({:ok, %{"id" => "123"}}, "User")
      {:ok, %{"id" => "123"}}

      iex> QlikElixir.REST.Helpers.normalize_get_response({:error, %Error{type: :file_not_found}}, "User")
      {:error, %Error{type: :not_found, message: "User not found"}}

  """
  @spec normalize_get_response({:ok, any()} | {:error, any()}, String.t()) :: {:ok, any()} | {:error, any()}
  def normalize_get_response({:ok, _} = success, _resource_name), do: success

  def normalize_get_response({:error, %Error{type: :file_not_found}}, resource_name) do
    {:error, %Error{type: :not_found, message: "#{resource_name} not found"}}
  end

  def normalize_get_response(error, _resource_name), do: error
end
