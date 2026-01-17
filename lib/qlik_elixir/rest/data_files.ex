defmodule QlikElixir.REST.DataFiles do
  @moduledoc """
  Qlik Cloud Data Files REST API client.

  Provides functions to manage data files including uploading, listing,
  updating, and organizing files across spaces.

  API Reference: https://qlik.dev/apis/rest/data-files/
  """

  alias QlikElixir.{Client, Config, Error}
  alias QlikElixir.REST.Helpers

  @base_path "api/v1/data-files"
  @max_file_size 500 * 1024 * 1024

  @doc """
  Lists data files.

  ## Options

    * `:connection_id` - Filter by connection ID
    * `:limit` - Maximum number of files to return
    * `:next` - Cursor for pagination
    * `:config` - Custom configuration

  ## Examples

      iex> QlikElixir.REST.DataFiles.list(connection_id: "conn-123")
      {:ok, %{"data" => [...]}}

  """
  @spec list(keyword()) :: {:ok, map()} | {:error, Error.t()}
  def list(opts \\ []) do
    query = Helpers.build_query(opts, [{:connectionId, :connection_id}])
    path = Helpers.build_path(@base_path, query)

    Client.get(path, Helpers.get_config(opts))
  end

  @doc """
  Gets details for a specific data file.

  ## Examples

      iex> QlikElixir.REST.DataFiles.get("file-123")
      {:ok, %{"id" => "file-123", "name" => "sales.csv"}}

  """
  @spec get(String.t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def get(file_id, opts \\ []) do
    Client.get("#{@base_path}/#{file_id}", Helpers.get_config(opts))
  end

  @doc """
  Uploads content as a new data file.

  ## Parameters

    * `content` - The file content (binary)
    * `filename` - Name for the file (must end with .csv)
    * `opts` - Options including `:config`, `:connection_id`

  ## Examples

      iex> QlikElixir.REST.DataFiles.upload("col1,col2\\nval1,val2", "data.csv")
      {:ok, %{"id" => "new-file"}}

  """
  @spec upload(binary(), String.t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def upload(content, filename, opts \\ []) do
    config = Helpers.get_config(opts)

    with :ok <- validate_file_size(byte_size(content)),
         :ok <- validate_filename(filename),
         {:ok, validated_config} <- Config.validate(config) do
      perform_upload(content, filename, validated_config, opts)
    end
  end

  @doc """
  Uploads a file from a file path.

  ## Options

    * `:name` - Custom filename (defaults to basename of file_path)
    * `:connection_id` - Data connection ID
    * `:config` - Custom configuration

  ## Examples

      iex> QlikElixir.REST.DataFiles.upload_file("/path/to/sales.csv")
      {:ok, %{"id" => "file-123"}}

  """
  @spec upload_file(String.t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def upload_file(file_path, opts \\ []) do
    with {:ok, %{size: size}} <- validate_file(file_path),
         :ok <- validate_file_size(size),
         {:ok, content} <- File.read(file_path) do
      filename = opts[:name] || Path.basename(file_path)
      upload(content, filename, opts)
    end
  end

  @doc """
  Updates (replaces) a data file's content.

  ## Examples

      iex> QlikElixir.REST.DataFiles.update("file-123", "new,content")
      {:ok, %{"id" => "file-123", "size" => 11}}

  """
  @spec update(String.t(), binary(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def update(file_id, content, opts \\ []) do
    multipart = [{"File", {content, [content_type: "text/csv"]}}]
    Client.put("#{@base_path}/#{file_id}", {:multipart, multipart}, Helpers.get_config(opts))
  end

  @doc """
  Deletes a data file.

  ## Examples

      iex> QlikElixir.REST.DataFiles.delete("file-123")
      :ok

  """
  @spec delete(String.t(), keyword()) :: :ok | {:error, Error.t()}
  def delete(file_id, opts \\ []) do
    "#{@base_path}/#{file_id}"
    |> Client.delete(Helpers.get_config(opts))
    |> Helpers.normalize_delete_response("Data file")
  end

  @doc """
  Changes the owner of a data file.

  ## Examples

      iex> QlikElixir.REST.DataFiles.change_owner("file-123", "user-456")
      {:ok, %{"id" => "file-123", "ownerId" => "user-456"}}

  """
  @spec change_owner(String.t(), String.t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def change_owner(file_id, owner_id, opts \\ []) do
    body = %{"ownerId" => owner_id}
    Client.post("#{@base_path}/#{file_id}/actions/change-owner", body, Helpers.get_config(opts))
  end

  @doc """
  Moves a data file to a different space.

  ## Examples

      iex> QlikElixir.REST.DataFiles.change_space("file-123", "space-456")
      {:ok, %{"id" => "file-123", "spaceId" => "space-456"}}

  """
  @spec change_space(String.t(), String.t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def change_space(file_id, space_id, opts \\ []) do
    body = %{"spaceId" => space_id}
    Client.post("#{@base_path}/#{file_id}/actions/change-space", body, Helpers.get_config(opts))
  end

  @doc """
  Deletes multiple data files in a batch.

  ## Examples

      iex> QlikElixir.REST.DataFiles.batch_delete(["file-1", "file-2"])
      {:ok, %{"deletedIds" => ["file-1", "file-2"]}}

  """
  @spec batch_delete(list(String.t()), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def batch_delete(file_ids, opts \\ []) do
    body = %{"ids" => file_ids}
    Client.post("#{@base_path}/actions/delete", body, Helpers.get_config(opts))
  end

  @doc """
  Moves multiple data files to a different space in a batch.

  ## Examples

      iex> QlikElixir.REST.DataFiles.batch_change_space(["file-1", "file-2"], "space-456")
      {:ok, %{"movedIds" => ["file-1", "file-2"]}}

  """
  @spec batch_change_space(list(String.t()), String.t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def batch_change_space(file_ids, space_id, opts \\ []) do
    body = %{"ids" => file_ids, "spaceId" => space_id}
    Client.post("#{@base_path}/actions/change-space", body, Helpers.get_config(opts))
  end

  @doc """
  Gets storage quotas for data files.

  ## Examples

      iex> QlikElixir.REST.DataFiles.get_quotas()
      {:ok, %{"maxBytes" => 10737418240, "usedBytes" => 1073741824}}

  """
  @spec get_quotas(keyword()) :: {:ok, map()} | {:error, Error.t()}
  def get_quotas(opts \\ []) do
    Client.get("#{@base_path}/quotas", Helpers.get_config(opts))
  end

  @doc """
  Lists data file connections.

  ## Examples

      iex> QlikElixir.REST.DataFiles.list_connections()
      {:ok, %{"data" => [%{"id" => "conn-1", "name" => "Personal Files"}]}}

  """
  @spec list_connections(keyword()) :: {:ok, map()} | {:error, Error.t()}
  def list_connections(opts \\ []) do
    Client.get("#{@base_path}/connections", Helpers.get_config(opts))
  end

  @doc """
  Finds a data file by name.

  ## Options

    * `:connection_id` - Filter by connection ID
    * `:config` - Custom configuration

  ## Examples

      iex> QlikElixir.REST.DataFiles.find_by_name("sales.csv")
      {:ok, %{"id" => "file-123", "name" => "sales.csv"}}

  """
  @spec find_by_name(String.t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def find_by_name(filename, opts \\ []) do
    case list(opts) do
      {:ok, %{"data" => files}} ->
        case Enum.find(files, &(&1["name"] == filename)) do
          nil -> {:error, Error.file_not_found("File not found: #{filename}")}
          file -> {:ok, file}
        end

      error ->
        error
    end
  end

  # Private helpers

  defp perform_upload(content, filename, config, opts) do
    connection_id = opts[:connection_id] || config.connection_id
    multipart = build_multipart(content, filename, connection_id)

    Client.post(@base_path, {:multipart, multipart}, config)
  end

  defp build_multipart(content, filename, connection_id) do
    json_data =
      %{"name" => filename}
      |> Helpers.put_if_present("connectionId", connection_id)

    [
      {"Json", {Jason.encode!(json_data), [content_type: "application/json"]}},
      {"File", {content, [filename: filename, content_type: "text/csv"]}}
    ]
  end

  defp validate_file(file_path) do
    case File.stat(file_path) do
      {:ok, %{type: :regular} = stat} ->
        {:ok, stat}

      {:ok, _stat} ->
        {:error, Error.validation_error("#{file_path} is not a regular file")}

      {:error, :enoent} ->
        {:error, Error.file_not_found("File not found: #{file_path}")}

      {:error, reason} ->
        {:error, Error.validation_error("Cannot access file: #{inspect(reason)}")}
    end
  end

  defp validate_file_size(size) when size > @max_file_size do
    {:error,
     Error.file_too_large(
       "File size (#{format_bytes(size)}) exceeds maximum allowed size (#{format_bytes(@max_file_size)})"
     )}
  end

  defp validate_file_size(_size), do: :ok

  defp validate_filename(filename) do
    if String.ends_with?(filename, ".csv") do
      :ok
    else
      {:error, Error.validation_error("Filename must end with .csv extension")}
    end
  end

  defp format_bytes(bytes) do
    cond do
      bytes >= 1024 * 1024 * 1024 -> "#{Float.round(bytes / (1024 * 1024 * 1024), 2)} GB"
      bytes >= 1024 * 1024 -> "#{Float.round(bytes / (1024 * 1024), 2)} MB"
      bytes >= 1024 -> "#{Float.round(bytes / 1024, 2)} KB"
      true -> "#{bytes} B"
    end
  end
end
