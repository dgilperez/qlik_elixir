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

      iex> config = QlikElixir.Config.new(api_key: "key", tenant_url: "https://example.com")
      iex> QlikElixir.REST.Helpers.get_config(config: config).api_key
      "key"

  """
  @spec get_config(keyword()) :: Config.t()
  def get_config(opts), do: Keyword.get(opts, :config) || Config.new()

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
  Normalizes a repeatable query parameter into the comma-separated form Qlik
  expects, leaving scalars and `nil` untouched.

  ## Examples

      iex> QlikElixir.REST.Helpers.join_param(["+name", "-updatedAt"])
      "+name,-updatedAt"

      iex> QlikElixir.REST.Helpers.join_param("+name")
      "+name"

      iex> QlikElixir.REST.Helpers.join_param(nil)
      nil

  """
  @spec join_param(nil | String.t() | list()) :: String.t() | nil
  def join_param(nil), do: nil
  def join_param(values) when is_list(values), do: Enum.join(values, ",")
  def join_param(value), do: value

  @doc """
  Builds a query string from options using a list of `{api_key, opts_key}` tuples.

  Cursor-paginated endpoints — most of them — get `limit` and `next` for free. Pass
  `base_mappings` to override that for an endpoint that pages differently, as the
  report templates one does with `skip`.

  List values are comma-joined, so a repeatable parameter can be given as a list.

  ## Examples

      iex> QlikElixir.REST.Helpers.build_query([limit: 10, space_id: "abc"], [{:spaceId, :space_id}])
      "limit=10&spaceId=abc"

      iex> QlikElixir.REST.Helpers.build_query([skip: 20], [{:skip, :skip}], [{:limit, :limit}])
      "skip=20"

      iex> QlikElixir.REST.Helpers.build_query([sort: ["+name", "-createdAt"]], [{:sort, :sort}])
      "sort=%2Bname%2C-createdAt"

  """
  @spec build_query(keyword(), list({atom(), atom()}), list({atom(), atom()})) :: String.t()
  def build_query(opts, param_mappings, base_mappings \\ [{:limit, :limit}, {:next, :next}]) do
    (base_mappings ++ param_mappings)
    |> Enum.reduce([], fn {api_key, opts_key}, acc ->
      add_param(acc, api_key, join_param(Keyword.get(opts, opts_key)))
    end)
    |> Enum.reverse()
    |> Pagination.build_query()
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
      value = fetch_param_value(params, param_key)
      put_if_present(acc, api_key, value)
    end)
  end

  defp fetch_param_value(params, key) do
    case Map.fetch(params, key) do
      {:ok, value} -> value
      :error -> Map.get(params, to_string(key))
    end
  end

  defp normalize_field_spec({api_key, param_key}) when is_binary(api_key), do: {api_key, param_key}
  defp normalize_field_spec(key) when is_atom(key), do: {to_string(key), key}

  @doc """
  Normalizes a delete response to `:ok` on success.

  Converts `:file_not_found` errors to `:not_found` with a custom message.

  ## Examples

      iex> QlikElixir.REST.Helpers.normalize_delete_response({:ok, %{}}, "User")
      :ok

      iex> {:error, error} = QlikElixir.REST.Helpers.normalize_delete_response({:error, %QlikElixir.Error{type: :file_not_found}}, "User")
      iex> {error.type, error.message}
      {:not_found, "User not found"}

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

      iex> {:error, error} = QlikElixir.REST.Helpers.normalize_get_response({:error, %QlikElixir.Error{type: :file_not_found}}, "User")
      iex> {error.type, error.message}
      {:not_found, "User not found"}

  """
  @spec normalize_get_response({:ok, any()} | {:error, any()}, String.t()) :: {:ok, any()} | {:error, any()}
  def normalize_get_response({:ok, _} = success, _resource_name), do: success

  def normalize_get_response({:error, %Error{type: :file_not_found}}, resource_name) do
    {:error, %Error{type: :not_found, message: "#{resource_name} not found"}}
  end

  def normalize_get_response(error, _resource_name), do: error

  # File validation helpers (shared by Uploader and DataFiles)

  @max_file_size 500 * 1024 * 1024

  @doc """
  Validates that a file path points to a regular file.

  ## Examples

      iex> {:ok, stat} = QlikElixir.REST.Helpers.validate_file("mix.exs")
      iex> stat.type
      :regular

      iex> {:error, error} = QlikElixir.REST.Helpers.validate_file("/nonexistent")
      iex> error.type
      :file_not_found

  """
  @spec validate_file(String.t()) :: {:ok, File.Stat.t()} | {:error, Error.t()}
  def validate_file(file_path) do
    case File.stat(file_path) do
      {:ok, %{type: :regular} = stat} -> {:ok, stat}
      {:ok, _} -> {:error, Error.validation_error("#{file_path} is not a regular file")}
      {:error, :enoent} -> {:error, Error.file_not_found("File not found: #{file_path}")}
      {:error, reason} -> {:error, Error.validation_error("Cannot access file: #{inspect(reason)}")}
    end
  end

  @doc """
  Validates file size against maximum allowed (500MB).
  """
  @spec validate_file_size(non_neg_integer()) :: :ok | {:error, Error.t()}
  def validate_file_size(size) when size > @max_file_size do
    {:error,
     Error.file_too_large(
       "File size (#{format_bytes(size)}) exceeds maximum allowed size (#{format_bytes(@max_file_size)})"
     )}
  end

  def validate_file_size(_size), do: :ok

  @doc """
  Validates that filename ends with .csv extension.
  """
  @spec validate_filename(String.t()) :: :ok | {:error, Error.t()}
  def validate_filename(filename) when is_binary(filename) do
    if String.ends_with?(filename, ".csv"),
      do: :ok,
      else: {:error, Error.validation_error("Filename must end with .csv extension")}
  end

  def validate_filename(_), do: {:error, Error.validation_error("Filename must end with .csv extension")}

  @doc """
  Formats bytes into human readable string (B, KB, MB, GB).
  """
  @spec format_bytes(non_neg_integer()) :: String.t()
  def format_bytes(bytes) do
    cond do
      bytes >= 1024 * 1024 * 1024 -> "#{Float.round(bytes / (1024 * 1024 * 1024), 2)} GB"
      bytes >= 1024 * 1024 -> "#{Float.round(bytes / (1024 * 1024), 2)} MB"
      bytes >= 1024 -> "#{Float.round(bytes / 1024, 2)} KB"
      true -> "#{bytes} B"
    end
  end
end
