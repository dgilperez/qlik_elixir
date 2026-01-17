defmodule QlikElixir.REST.Collections do
  @moduledoc """
  REST API client for Qlik Cloud Collections.

  Collections allow users to organize and group items (apps, data files, etc.)
  for easier access and sharing.

  ## Examples

      # List all collections
      {:ok, %{"data" => collections}} = Collections.list(config: config)

      # Create a collection
      {:ok, collection} = Collections.create(%{name: "My Reports", type: "private"}, config: config)

      # Add items to a collection
      {:ok, _} = Collections.add_items("coll-123", ["item-1", "item-2"], config: config)

      # Get favorites collection
      {:ok, favorites} = Collections.get_favorites(config: config)

  """

  alias QlikElixir.{Client, Error}
  alias QlikElixir.REST.Helpers

  @base_path "api/v1/collections"

  @doc """
  Lists all collections.

  ## Options

    * `:config` - Required. The configuration struct.
    * `:limit` - Maximum number of results per page.
    * `:next` - Cursor for pagination.
    * `:name` - Filter by name (partial match).
    * `:type` - Filter by type ("private", "public", "favorite").
    * `:sort` - Sort order (e.g., "-createdAt").

  """
  @spec list(keyword()) :: {:ok, map()} | {:error, Error.t()}
  def list(opts \\ []) do
    query =
      Helpers.build_query(opts, [
        {:name, :name},
        {:type, :type},
        {:sort, :sort}
      ])

    path = Helpers.build_path(@base_path, query)
    Client.get(path, Helpers.get_config(opts))
  end

  @doc """
  Gets a collection by ID.
  """
  @spec get(String.t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def get(collection_id, opts \\ []) do
    "#{@base_path}/#{collection_id}"
    |> Client.get(Helpers.get_config(opts))
    |> Helpers.normalize_get_response("Collection")
  end

  @doc """
  Creates a new collection.

  ## Parameters

    * `params` - Map with collection details:
      * `:name` - Required. Collection name.
      * `:type` - Collection type ("private" or "public").
      * `:description` - Optional description.

  """
  @spec create(map(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def create(params, opts \\ []) do
    body = Helpers.build_body(params, [:name, :type, :description])
    Client.post(@base_path, body, Helpers.get_config(opts))
  end

  @doc """
  Updates a collection.

  ## Parameters

    * `collection_id` - The collection ID.
    * `params` - Map with fields to update.

  """
  @spec update(String.t(), map(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def update(collection_id, params, opts \\ []) do
    path = "#{@base_path}/#{collection_id}"
    body = Helpers.build_body(params, [:name, :description])
    Client.put(path, body, Helpers.get_config(opts))
  end

  @doc """
  Deletes a collection.
  """
  @spec delete(String.t(), keyword()) :: :ok | {:error, Error.t()}
  def delete(collection_id, opts \\ []) do
    "#{@base_path}/#{collection_id}"
    |> Client.delete(Helpers.get_config(opts))
    |> Helpers.normalize_delete_response("Collection")
  end

  @doc """
  Lists items in a collection.

  ## Options

    * `:limit` - Maximum number of results per page.
    * `:next` - Cursor for pagination.

  """
  @spec list_items(String.t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def list_items(collection_id, opts \\ []) do
    query = Helpers.build_query(opts, [])
    path = Helpers.build_path("#{@base_path}/#{collection_id}/items", query)
    Client.get(path, Helpers.get_config(opts))
  end

  @doc """
  Adds items to a collection.

  ## Parameters

    * `collection_id` - The collection ID.
    * `item_ids` - List of item IDs to add.

  """
  @spec add_items(String.t(), list(String.t()), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def add_items(collection_id, item_ids, opts \\ []) when is_list(item_ids) do
    path = "#{@base_path}/#{collection_id}/items"
    body = %{"items" => item_ids}
    Client.post(path, body, Helpers.get_config(opts))
  end

  @doc """
  Removes an item from a collection.

  ## Parameters

    * `collection_id` - The collection ID.
    * `item_id` - The item ID to remove.

  """
  @spec remove_item(String.t(), String.t(), keyword()) :: :ok | {:error, Error.t()}
  def remove_item(collection_id, item_id, opts \\ []) do
    "#{@base_path}/#{collection_id}/items/#{item_id}"
    |> Client.delete(Helpers.get_config(opts))
    |> Helpers.normalize_delete_response("Item")
  end

  @doc """
  Gets the user's favorites collection.
  """
  @spec get_favorites(keyword()) :: {:ok, map()} | {:error, Error.t()}
  def get_favorites(opts \\ []) do
    Client.get("#{@base_path}/favorites", Helpers.get_config(opts))
  end
end
