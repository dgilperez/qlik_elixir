defmodule QlikElixir.REST.Items do
  @moduledoc """
  REST API client for Qlik Cloud Items (Unified Resources).

  Items represent a unified view of all resources in Qlik Cloud (apps, spaces,
  data files, etc.). This API provides a consistent way to query and manage
  resources across different types.

  ## Examples

      # List all items
      {:ok, %{"data" => items}} = Items.list(config: config)

      # Filter by resource type
      {:ok, %{"data" => apps}} = Items.list(config: config, resource_type: "app")

      # Get item details
      {:ok, item} = Items.get("item-123", config: config)

      # Get collections containing an item
      {:ok, %{"data" => collections}} = Items.get_collections("item-123", config: config)

  """

  alias QlikElixir.{Client, Error}
  alias QlikElixir.REST.Helpers

  @base_path "api/v1/items"

  @doc """
  Lists all items.

  ## Options

    * `:config` - Required. The configuration struct.
    * `:limit` - Maximum number of results per page.
    * `:next` - Cursor for pagination.
    * `:resource_type` - Filter by resource type (e.g., "app", "space", "datafile").
    * `:resource_id` - Filter by resource ID (requires resource_type).
    * `:space_id` - Filter by space ID.
    * `:name` - Filter by name (partial match).
    * `:owner_id` - Filter by owner ID.
    * `:shared` - Filter by shared status.
    * `:sort` - Sort order (e.g., "-updatedAt" for descending).

  """
  @spec list(keyword()) :: {:ok, map()} | {:error, Error.t()}
  def list(opts \\ []) do
    query =
      Helpers.build_query(opts, [
        {:resourceType, :resource_type},
        {:resourceId, :resource_id},
        {:spaceId, :space_id},
        {:name, :name},
        {:ownerId, :owner_id},
        {:shared, :shared},
        {:sort, :sort}
      ])

    path = Helpers.build_path(@base_path, query)
    Client.get(path, Helpers.get_config(opts))
  end

  @doc """
  Gets an item by ID.
  """
  @spec get(String.t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def get(item_id, opts \\ []) do
    "#{@base_path}/#{item_id}"
    |> Client.get(Helpers.get_config(opts))
    |> Helpers.normalize_get_response("Item")
  end

  @doc """
  Finds an item by its resource ID and type.

  ## Parameters

    * `resource_id` - The resource ID (e.g., app ID, datafile ID).
    * `resource_type` - The resource type (e.g., "app", "datafile").

  ## Examples

      iex> Items.find_by_resource("app-123", "app", config: config)
      {:ok, %{"id" => "item-456", "resourceId" => "app-123"}}

  """
  @spec find_by_resource(String.t(), String.t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def find_by_resource(resource_id, resource_type, opts \\ []) do
    case list(Keyword.merge(opts, resource_id: resource_id, resource_type: resource_type, limit: 1)) do
      {:ok, %{"data" => [item | _]}} -> {:ok, item}
      {:ok, %{"data" => []}} -> {:error, QlikElixir.Error.not_found("Item not found for resource")}
      error -> error
    end
  end

  @doc """
  Updates an item.

  ## Parameters

    * `item_id` - The item ID.
    * `params` - Map with fields to update:
      * `:name` - New name.
      * `:description` - New description.

  """
  @spec update(String.t(), map(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def update(item_id, params, opts \\ []) do
    path = "#{@base_path}/#{item_id}"
    body = Helpers.build_body(params, [:name, :description])
    Client.put(path, body, Helpers.get_config(opts))
  end

  @doc """
  Deletes an item.
  """
  @spec delete(String.t(), keyword()) :: :ok | {:error, Error.t()}
  def delete(item_id, opts \\ []) do
    "#{@base_path}/#{item_id}"
    |> Client.delete(Helpers.get_config(opts))
    |> Helpers.normalize_delete_response("Item")
  end

  @doc """
  Gets published items for a resource.

  Returns all spaces where this item has been published.
  """
  @spec get_published_items(String.t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def get_published_items(item_id, opts \\ []) do
    path = "#{@base_path}/#{item_id}/publisheditems"
    Client.get(path, Helpers.get_config(opts))
  end

  @doc """
  Gets collections containing this item.
  """
  @spec get_collections(String.t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def get_collections(item_id, opts \\ []) do
    path = "#{@base_path}/#{item_id}/collections"
    Client.get(path, Helpers.get_config(opts))
  end
end
