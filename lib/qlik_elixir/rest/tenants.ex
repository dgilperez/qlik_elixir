defmodule QlikElixir.REST.Tenants do
  @moduledoc """
  REST API client for Qlik Cloud Tenants.

  Provides functions to manage tenant configuration and settings.

  ## Examples

      # Get current tenant
      {:ok, tenant} = Tenants.me(config: config)

      # Get tenant by ID
      {:ok, tenant} = Tenants.get("tenant-123", config: config)

      # Update tenant settings
      {:ok, tenant} = Tenants.update("tenant-123", %{name: "New Name"}, config: config)

  """

  alias QlikElixir.{Client, Error}
  alias QlikElixir.REST.Helpers

  @base_path "api/v1/tenants"

  @doc """
  Gets the current tenant (the one the API key belongs to).
  """
  @spec me(keyword()) :: {:ok, map()} | {:error, Error.t()}
  def me(opts \\ []) do
    Client.get("#{@base_path}/me", Helpers.get_config(opts))
  end

  @doc """
  Gets a tenant by ID.
  """
  @spec get(String.t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def get(tenant_id, opts \\ []) do
    "#{@base_path}/#{tenant_id}"
    |> Client.get(Helpers.get_config(opts))
    |> Helpers.normalize_get_response("Tenant")
  end

  @doc """
  Creates a new tenant.

  ## Parameters

    * `params` - Map with tenant details:
      * `:name` - Required. Tenant name.
      * `:licenseKey` - Required. License key.

  """
  @spec create(map(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def create(params, opts \\ []) do
    body = Helpers.build_body(params, [:name, :licenseKey])
    Client.post(@base_path, body, Helpers.get_config(opts))
  end

  @doc """
  Updates a tenant.

  ## Parameters

    * `tenant_id` - The tenant ID.
    * `params` - Map with fields to update.

  """
  @spec update(String.t(), map(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def update(tenant_id, params, opts \\ []) do
    path = "#{@base_path}/#{tenant_id}"
    body = Helpers.build_body(params, [:name])
    Client.patch(path, body, Helpers.get_config(opts))
  end

  @doc """
  Deactivates a tenant.
  """
  @spec deactivate(String.t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def deactivate(tenant_id, opts \\ []) do
    path = "#{@base_path}/#{tenant_id}/actions/deactivate"
    Client.post(path, %{}, Helpers.get_config(opts))
  end

  @doc """
  Reactivates a deactivated tenant.
  """
  @spec reactivate(String.t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def reactivate(tenant_id, opts \\ []) do
    path = "#{@base_path}/#{tenant_id}/actions/reactivate"
    Client.post(path, %{}, Helpers.get_config(opts))
  end
end
