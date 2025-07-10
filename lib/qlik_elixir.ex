defmodule QlikElixir do
  @moduledoc """
  An Elixir client library for uploading CSV files to Qlik Cloud.

  ## Installation

  Add `qlik_elixir` to your list of dependencies in `mix.exs`:

      def deps do
        [
          {:qlik_elixir, "~> 0.1.0"}
        ]
      end

  ## Configuration

  Configure the client using environment variables:

      export QLIK_API_KEY="your-api-key"
      export QLIK_TENANT_URL="https://your-tenant.qlikcloud.com"
      export QLIK_CONNECTION_ID="your-connection-id"  # Optional

  Or configure in your application config:

      config :qlik_elixir,
        api_key: "your-api-key",
        tenant_url: "https://your-tenant.qlikcloud.com",
        connection_id: "your-connection-id"

  ## Usage

      # Upload a file
      {:ok, %{"id" => file_id}} = QlikElixir.upload_csv("data.csv")

      # Upload with options
      QlikElixir.upload_csv("data.csv",
        name: "custom_name.csv",
        connection_id: "space-123",
        overwrite: true
      )

      # Upload content directly
      csv_content = "header1,header2\\nvalue1,value2"
      QlikElixir.upload_csv_content(csv_content, "dynamic.csv")

      # List files
      {:ok, files} = QlikElixir.list_files()

      # Check if file exists
      QlikElixir.file_exists?("data.csv")

      # Delete a file
      QlikElixir.delete_file("file-id-123")
  """

  alias QlikElixir.{Client, Config, Error, Uploader}

  @doc """
  Uploads a CSV file from a file path.

  ## Options

    * `:name` - Custom filename for the upload (defaults to original filename)
    * `:connection_id` - Qlik connection ID (overrides configured default)
    * `:overwrite` - Whether to overwrite existing files (default: false)
    * `:config` - Custom configuration (overrides defaults)

  ## Examples

      iex> QlikElixir.upload_csv("data.csv")
      {:ok, %{"id" => "file-123", "name" => "data.csv", "size" => 1024}}

      iex> QlikElixir.upload_csv("data.csv", name: "renamed.csv", overwrite: true)
      {:ok, %{"id" => "file-456", "name" => "renamed.csv", "size" => 1024}}

  """
  @spec upload_csv(String.t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def upload_csv(file_path, opts \\ []) do
    config = get_config(opts)
    Uploader.upload_file(file_path, config, opts)
  end

  @doc """
  Uploads CSV content directly.

  ## Options

    * `:connection_id` - Qlik connection ID (overrides configured default)
    * `:overwrite` - Whether to overwrite existing files (default: false)
    * `:config` - Custom configuration (overrides defaults)

  ## Examples

      iex> content = "id,name\\n1,John\\n2,Jane"
      iex> QlikElixir.upload_csv_content(content, "users.csv")
      {:ok, %{"id" => "file-789", "name" => "users.csv", "size" => 28}}

  """
  @spec upload_csv_content(binary(), String.t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def upload_csv_content(content, filename, opts \\ []) do
    config = get_config(opts)
    Uploader.upload_content(content, filename, config, opts)
  end

  @doc """
  Lists uploaded files.

  ## Options

    * `:limit` - Maximum number of files to return (default: 100)
    * `:offset` - Number of files to skip (default: 0)
    * `:config` - Custom configuration (overrides defaults)

  ## Examples

      iex> QlikElixir.list_files()
      {:ok, %{
        "data" => [
          %{"id" => "file-123", "name" => "data.csv", "size" => 1024},
          %{"id" => "file-456", "name" => "users.csv", "size" => 2048}
        ],
        "total" => 2
      }}

      iex> QlikElixir.list_files(limit: 10, offset: 20)
      {:ok, %{"data" => [%{"id" => "file-789", "name" => "logs.csv", "size" => 512}], "total" => 50}}

  """
  @spec list_files(keyword()) :: {:ok, map()} | {:error, Error.t()}
  def list_files(opts \\ []) do
    config = get_config(opts)
    limit = Keyword.get(opts, :limit, 100)
    offset = Keyword.get(opts, :offset, 0)

    Client.get("api/v1/data-files?limit=#{limit}&offset=#{offset}", config)
  end

  @doc """
  Deletes a file by ID.

  ## Examples

      iex> QlikElixir.delete_file("file-123")
      :ok

      iex> QlikElixir.delete_file("non-existent")
      {:error, %QlikElixir.Error{type: :file_not_found}}

  """
  @spec delete_file(String.t(), keyword()) :: :ok | {:error, Error.t()}
  def delete_file(file_id, opts \\ []) do
    config = get_config(opts)

    case Client.delete("api/v1/data-files/#{file_id}", config) do
      {:ok, _} -> :ok
      error -> error
    end
  end

  @doc """
  Checks if a file exists by name.

  ## Examples

      iex> QlikElixir.file_exists?("data.csv")
      true

      iex> QlikElixir.file_exists?("non-existent.csv")
      false

  """
  @spec file_exists?(String.t(), keyword()) :: boolean()
  def file_exists?(filename, opts \\ []) do
    case find_file_by_name(filename, opts) do
      {:ok, _} -> true
      _ -> false
    end
  end

  @doc """
  Finds a file by name.

  ## Examples

      iex> QlikElixir.find_file_by_name("data.csv")
      {:ok, %{"id" => "file-123", "name" => "data.csv", "size" => 1024}}

      iex> QlikElixir.find_file_by_name("non-existent.csv")
      {:error, %QlikElixir.Error{type: :file_not_found}}

  """
  @spec find_file_by_name(String.t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def find_file_by_name(filename, opts \\ []) do
    config = get_config(opts)

    case Client.get("api/v1/data-files?limit=100", config) do
      {:ok, %{"data" => files}} ->
        case Enum.find(files, fn file -> file["name"] == filename end) do
          nil -> {:error, Error.file_not_found("File not found: #{filename}")}
          file -> {:ok, file}
        end

      error ->
        error
    end
  end

  @doc """
  Creates a new configuration struct.

  This is useful when you need to work with multiple Qlik tenants or want to
  override the default configuration.

  ## Examples

      iex> config = QlikElixir.Config.new(
      ...>   api_key: "different-key",
      ...>   tenant_url: "https://other-tenant.qlikcloud.com"
      ...> )
      iex> QlikElixir.upload_csv("data.csv", config: config)

  """
  defdelegate new_config(opts), to: Config, as: :new

  defp get_config(opts) do
    case Keyword.get(opts, :config) do
      %Config{} = config -> config
      nil -> Config.new()
    end
  end
end
