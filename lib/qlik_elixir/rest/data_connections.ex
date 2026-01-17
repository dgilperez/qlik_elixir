defmodule QlikElixir.REST.DataConnections do
  @moduledoc """
  REST API client for Qlik Cloud Data Connections.

  Provides functions to manage data connections which define how Qlik apps
  connect to external data sources.

  ## Examples

      # List all data connections
      {:ok, %{"data" => connections}} = DataConnections.list(config: config)

      # Get connection details
      {:ok, connection} = DataConnections.get("conn-123", config: config)

      # Create a connection
      params = %{
        qName: "MyPostgres",
        qType: "PostgreSQL",
        qConnectStatement: "CONNECT TO 'Provider=PostgreSQL;Host=...';"
      }
      {:ok, connection} = DataConnections.create(params, config: config)

      # Duplicate a connection
      {:ok, copy} = DataConnections.duplicate("conn-123", config: config, name: "Copy")

  """

  alias QlikElixir.{Client, Error}
  alias QlikElixir.REST.Helpers

  @base_path "api/v1/data-connections"

  @doc """
  Lists all data connections.

  ## Options

    * `:config` - Required. The configuration struct.
    * `:limit` - Maximum number of results per page.
    * `:next` - Cursor for pagination.
    * `:space_id` - Filter by space ID.
    * `:name` - Filter by connection name.
    * `:qType` - Filter by connection type.

  """
  @spec list(keyword()) :: {:ok, map()} | {:error, Error.t()}
  def list(opts \\ []) do
    query =
      Helpers.build_query(opts, [
        {:spaceId, :space_id},
        {:name, :name},
        {:qType, :qType}
      ])

    path = Helpers.build_path(@base_path, query)
    Client.get(path, Helpers.get_config(opts))
  end

  @doc """
  Gets a data connection by ID.
  """
  @spec get(String.t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def get(connection_id, opts \\ []) do
    "#{@base_path}/#{connection_id}"
    |> Client.get(Helpers.get_config(opts))
    |> Helpers.normalize_get_response("Data connection")
  end

  @doc """
  Creates a new data connection.

  ## Parameters

    * `params` - Map with connection details:
      * `:qName` - Required. Connection name.
      * `:qType` - Required. Connection type (e.g., "PostgreSQL", "folder").
      * `:qConnectStatement` - Required. Connection string.
      * `:spaceId` - Optional. Target space ID.

  """
  @spec create(map(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def create(params, opts \\ []) do
    body = Helpers.build_body(params, [:qName, :qType, :qConnectStatement, :spaceId, :qUsername, :qPassword])
    Client.post(@base_path, body, Helpers.get_config(opts))
  end

  @doc """
  Updates a data connection.

  ## Parameters

    * `connection_id` - The connection ID.
    * `params` - Map with fields to update.

  """
  @spec update(String.t(), map(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def update(connection_id, params, opts \\ []) do
    path = "#{@base_path}/#{connection_id}"
    body = Helpers.build_body(params, [:qName, :qConnectStatement, :qUsername, :qPassword])
    Client.patch(path, body, Helpers.get_config(opts))
  end

  @doc """
  Deletes a data connection.
  """
  @spec delete(String.t(), keyword()) :: :ok | {:error, Error.t()}
  def delete(connection_id, opts \\ []) do
    "#{@base_path}/#{connection_id}"
    |> Client.delete(Helpers.get_config(opts))
    |> Helpers.normalize_delete_response("Data connection")
  end

  @doc """
  Duplicates a data connection.

  ## Options

    * `:name` - Custom name for the copy.
    * `:space_id` - Target space for the copy.

  """
  @spec duplicate(String.t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def duplicate(connection_id, opts \\ []) do
    path = "#{@base_path}/#{connection_id}/actions/duplicate"

    body =
      %{}
      |> Helpers.put_if_present("qName", opts[:name])
      |> Helpers.put_if_present("spaceId", opts[:space_id])

    Client.post(path, body, Helpers.get_config(opts))
  end

  @doc """
  Deletes multiple data connections.

  ## Parameters

    * `connection_ids` - List of connection IDs to delete.

  """
  @spec batch_delete(list(String.t()), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def batch_delete(connection_ids, opts \\ []) when is_list(connection_ids) do
    path = "#{@base_path}/actions/delete"
    body = %{"ids" => connection_ids}
    Client.post(path, body, Helpers.get_config(opts))
  end

  @doc """
  Updates multiple data connections.

  ## Parameters

    * `updates` - List of update objects with `:id` and fields to update.

  """
  @spec batch_update(list(map()), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def batch_update(updates, opts \\ []) when is_list(updates) do
    body = %{"updates" => updates}
    Client.patch(@base_path, body, Helpers.get_config(opts))
  end

  @doc """
  Moves a data connection to another space.

  ## Parameters

    * `connection_id` - The connection ID.
    * `space_id` - The target space ID.

  """
  @spec change_space(String.t(), String.t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def change_space(connection_id, space_id, opts \\ []) do
    path = "#{@base_path}/#{connection_id}/actions/change-space"
    body = %{"spaceId" => space_id}
    Client.post(path, body, Helpers.get_config(opts))
  end

  @doc """
  Changes the owner of a data connection.

  ## Parameters

    * `connection_id` - The connection ID.
    * `owner_id` - The new owner's user ID.

  """
  @spec change_owner(String.t(), String.t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def change_owner(connection_id, owner_id, opts \\ []) do
    path = "#{@base_path}/#{connection_id}/actions/change-owner"
    body = %{"ownerId" => owner_id}
    Client.post(path, body, Helpers.get_config(opts))
  end
end
