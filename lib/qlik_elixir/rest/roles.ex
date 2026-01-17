defmodule QlikElixir.REST.Roles do
  @moduledoc """
  REST API client for Qlik Cloud Roles.

  Provides functions to query available roles for user assignment.
  Roles in Qlik Cloud are predefined and cannot be created or modified.

  ## Examples

      # List all roles
      {:ok, %{"data" => roles}} = Roles.list(config: config)

      # Get role details
      {:ok, role} = Roles.get("role-123", config: config)

  """

  alias QlikElixir.{Client, Error}
  alias QlikElixir.REST.Helpers

  @base_path "api/v1/roles"

  @doc """
  Lists all available roles.

  ## Options

    * `:config` - Required. The configuration struct.
    * `:limit` - Maximum number of results per page.
    * `:next` - Cursor for pagination.
    * `:name` - Filter by role name.
    * `:type` - Filter by role type (e.g., "default").

  """
  @spec list(keyword()) :: {:ok, map()} | {:error, Error.t()}
  def list(opts \\ []) do
    query = Helpers.build_query(opts, [{:name, :name}, {:type, :type}])
    path = Helpers.build_path(@base_path, query)
    Client.get(path, Helpers.get_config(opts))
  end

  @doc """
  Gets a role by ID.
  """
  @spec get(String.t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def get(role_id, opts \\ []) do
    "#{@base_path}/#{role_id}"
    |> Client.get(Helpers.get_config(opts))
    |> Helpers.normalize_get_response("Role")
  end
end
