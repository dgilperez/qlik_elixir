defmodule QlikElixir.REST.Groups do
  @moduledoc """
  REST API client for Qlik Cloud Groups.

  Provides functions to manage user groups for access control.

  ## Examples

      # List all groups
      {:ok, %{"data" => groups}} = Groups.list(config: config)

      # Get group details
      {:ok, group} = Groups.get("group-123", config: config)

      # Create a group
      {:ok, group} = Groups.create(%{name: "Developers"}, config: config)

      # Get group settings
      {:ok, settings} = Groups.list_settings(config: config)

  """

  alias QlikElixir.{Client, Error}
  alias QlikElixir.REST.Helpers

  @base_path "api/v1/groups"

  @doc """
  Lists all groups.

  ## Options

    * `:config` - Required. The configuration struct.
    * `:limit` - Maximum number of results per page.
    * `:next` - Cursor for pagination.
    * `:name` - Filter by group name.

  """
  @spec list(keyword()) :: {:ok, map()} | {:error, Error.t()}
  def list(opts \\ []) do
    query = Helpers.build_query(opts, [{:name, :name}])
    path = Helpers.build_path(@base_path, query)
    Client.get(path, Helpers.get_config(opts))
  end

  @doc """
  Gets a group by ID.
  """
  @spec get(String.t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def get(group_id, opts \\ []) do
    "#{@base_path}/#{group_id}"
    |> Client.get(Helpers.get_config(opts))
    |> Helpers.normalize_get_response("Group")
  end

  @doc """
  Creates a new group.

  ## Parameters

    * `params` - Map with group details:
      * `:name` - Required. Group name.

  """
  @spec create(map(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def create(params, opts \\ []) do
    body = Helpers.build_body(params, [:name])
    Client.post(@base_path, body, Helpers.get_config(opts))
  end

  @doc """
  Updates a group.

  ## Parameters

    * `group_id` - The group ID.
    * `params` - Map with fields to update.

  """
  @spec update(String.t(), map(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def update(group_id, params, opts \\ []) do
    path = "#{@base_path}/#{group_id}"
    body = Helpers.build_body(params, [:name])
    Client.patch(path, body, Helpers.get_config(opts))
  end

  @doc """
  Deletes a group.
  """
  @spec delete(String.t(), keyword()) :: :ok | {:error, Error.t()}
  def delete(group_id, opts \\ []) do
    "#{@base_path}/#{group_id}"
    |> Client.delete(Helpers.get_config(opts))
    |> Helpers.normalize_delete_response("Group")
  end

  @doc """
  Gets group settings for the tenant.
  """
  @spec list_settings(keyword()) :: {:ok, map()} | {:error, Error.t()}
  def list_settings(opts \\ []) do
    Client.get("#{@base_path}/settings", Helpers.get_config(opts))
  end

  @doc """
  Updates group settings for the tenant.

  ## Parameters

    * `params` - Map with settings to update:
      * `:autoCreateGroups` - Whether to auto-create groups from IdP.
      * `:syncIdpGroups` - Whether to sync groups from IdP.

  """
  @spec update_settings(map(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def update_settings(params, opts \\ []) do
    body = Helpers.build_body(params, [:autoCreateGroups, :syncIdpGroups])
    Client.patch("#{@base_path}/settings", body, Helpers.get_config(opts))
  end
end
