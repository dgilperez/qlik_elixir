defmodule QlikElixir.REST.APIKeys do
  @moduledoc """
  REST API client for Qlik Cloud API Keys.

  Provides functions to manage API keys for programmatic access to Qlik Cloud.

  ## Examples

      # List all API keys
      {:ok, %{"data" => keys}} = APIKeys.list(config: config)

      # Create a new API key
      {:ok, key} = APIKeys.create(%{description: "My API Key"}, config: config)
      # key["token"] contains the generated JWT token (only shown once)

      # Delete an API key
      :ok = APIKeys.delete("key-123", config: config)

      # Get tenant configuration (requires tenant ID from Tenants.me)
      {:ok, tenant} = Tenants.me(config: config)
      {:ok, config} = APIKeys.get_config(tenant["id"], config: config)

  """

  alias QlikElixir.{Client, Error}
  alias QlikElixir.REST.Helpers

  @base_path "api/v1/api-keys"

  @doc """
  Lists all API keys.

  ## Options

    * `:config` - Required. The configuration struct.
    * `:limit` - Maximum number of results per page.
    * `:next` - Cursor for pagination.
    * `:owner_id` - Filter by owner ID.
    * `:status` - Filter by status ("active", "expired", "revoked").
    * `:sort` - Sort field and direction (e.g., "-createdAt").

  """
  @spec list(keyword()) :: {:ok, map()} | {:error, Error.t()}
  def list(opts \\ []) do
    query =
      Helpers.build_query(opts, [
        {:ownerId, :owner_id},
        {:status, :status},
        {:sort, :sort}
      ])

    path = Helpers.build_path(@base_path, query)
    Client.get(path, Helpers.get_config(opts))
  end

  @doc """
  Gets an API key by ID.
  """
  @spec get(String.t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def get(key_id, opts \\ []) do
    "#{@base_path}/#{key_id}"
    |> Client.get(Helpers.get_config(opts))
    |> Helpers.normalize_get_response("API key")
  end

  @doc """
  Creates a new API key.

  ## Parameters

    * `params` - Map with key details:
      * `:description` - Required. Description of the key.
      * `:expiry` - Optional. Expiration timestamp (ISO 8601).
      * `:sub` - Optional. Subject to generate key for (admin only).

  ## Returns

  The response includes a `token` field containing the JWT token.
  This token is only shown once and cannot be retrieved again.

  """
  @spec create(map(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def create(params, opts \\ []) do
    body = Helpers.build_body(params, [:description, :expiry, :sub])
    Client.post(@base_path, body, Helpers.get_config(opts))
  end

  @doc """
  Updates an API key.

  ## Parameters

    * `key_id` - The API key ID.
    * `params` - Map with fields to update:
      * `:description` - New description.

  """
  @spec update(String.t(), map(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def update(key_id, params, opts \\ []) do
    path = "#{@base_path}/#{key_id}"
    body = Helpers.build_body(params, [:description])
    Client.patch(path, body, Helpers.get_config(opts))
  end

  @doc """
  Deletes an API key.
  """
  @spec delete(String.t(), keyword()) :: :ok | {:error, Error.t()}
  def delete(key_id, opts \\ []) do
    "#{@base_path}/#{key_id}"
    |> Client.delete(Helpers.get_config(opts))
    |> Helpers.normalize_delete_response("API key")
  end

  @doc """
  Gets the API keys configuration for a tenant.

  ## Parameters

    * `tenant_id` - The tenant ID. Use `Tenants.me/1` to get the current tenant ID.

  ## Examples

      {:ok, tenant} = Tenants.me(config: config)
      {:ok, config} = APIKeys.get_config(tenant["id"], config: config)

  """
  @spec get_config(String.t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def get_config(tenant_id, opts \\ []) when is_binary(tenant_id) do
    path = "#{@base_path}/configs/#{tenant_id}"
    Client.get(path, Helpers.get_config(opts))
  end

  @doc """
  Updates the API keys configuration for a tenant.

  ## Parameters

    * `tenant_id` - The tenant ID.
    * `params` - Map with configuration fields:
      * `:api_keys_enabled` - Enable/disable API keys.
      * `:max_api_key_expiry` - Maximum expiry duration.
      * `:max_keys_per_user` - Maximum keys per user.

  """
  @spec update_config(String.t(), map(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def update_config(tenant_id, params, opts \\ []) when is_binary(tenant_id) do
    path = "#{@base_path}/configs/#{tenant_id}"
    body = Helpers.build_body(params, [:api_keys_enabled, :max_api_key_expiry, :max_keys_per_user])
    Client.patch(path, body, Helpers.get_config(opts))
  end
end
