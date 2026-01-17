defmodule QlikElixir.REST.Apps do
  @moduledoc """
  Qlik Cloud Apps REST API client.

  Provides functions to manage Qlik Sense applications including
  listing, creating, updating, copying, and deleting apps.

  API Reference: https://qlik.dev/apis/rest/apps/
  """

  alias QlikElixir.{Client, Error}
  alias QlikElixir.REST.Helpers

  @base_path "api/v1/apps"

  @doc """
  Lists apps accessible to the current user.

  ## Options

    * `:limit` - Maximum number of apps to return (default: 100)
    * `:next` - Cursor for pagination
    * `:space_id` - Filter by space ID
    * `:name` - Filter by app name
    * `:config` - Custom configuration

  ## Examples

      iex> QlikElixir.REST.Apps.list(limit: 10)
      {:ok, %{"data" => [...]}}

  """
  @spec list(keyword()) :: {:ok, map()} | {:error, Error.t()}
  def list(opts \\ []) do
    query = Helpers.build_query(opts, [{:spaceId, :space_id}, {:name, :name}])
    path = Helpers.build_path(@base_path, query)

    Client.get(path, Helpers.get_config(opts))
  end

  @doc """
  Gets details for a specific app.

  ## Examples

      iex> QlikElixir.REST.Apps.get("app-123")
      {:ok, %{"id" => "app-123", "name" => "My App"}}

  """
  @spec get(String.t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def get(app_id, opts \\ []) do
    "#{@base_path}/#{app_id}"
    |> Client.get(Helpers.get_config(opts))
    |> Helpers.normalize_get_response("App")
  end

  @doc """
  Creates a new app.

  ## Parameters

    * `params` - Map with app attributes:
      * `:name` - App name (required)
      * `:description` - App description
      * `:space_id` - Space to create the app in

  ## Examples

      iex> QlikElixir.REST.Apps.create(%{name: "New App"})
      {:ok, %{"id" => "new-id", "name" => "New App"}}

  """
  @spec create(map(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def create(params, opts \\ []) do
    body = build_attributes_body(params)
    Client.post(@base_path, body, Helpers.get_config(opts))
  end

  @doc """
  Updates an existing app.

  ## Examples

      iex> QlikElixir.REST.Apps.update("app-123", %{name: "Renamed"})
      {:ok, %{"id" => "app-123", "name" => "Renamed"}}

  """
  @spec update(String.t(), map(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def update(app_id, params, opts \\ []) do
    body = build_attributes_body(params)
    Client.put("#{@base_path}/#{app_id}", body, Helpers.get_config(opts))
  end

  @doc """
  Deletes an app.

  ## Examples

      iex> QlikElixir.REST.Apps.delete("app-123")
      :ok

  """
  @spec delete(String.t(), keyword()) :: :ok | {:error, Error.t()}
  def delete(app_id, opts \\ []) do
    "#{@base_path}/#{app_id}"
    |> Client.delete(Helpers.get_config(opts))
    |> Helpers.normalize_delete_response("App")
  end

  @doc """
  Copies an app.

  ## Options

    * `:name` - Name for the copied app
    * `:space_id` - Target space for the copy
    * `:config` - Custom configuration

  ## Examples

      iex> QlikElixir.REST.Apps.copy("app-123", name: "Copy of App")
      {:ok, %{"id" => "new-id", "name" => "Copy of App"}}

  """
  @spec copy(String.t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def copy(app_id, opts \\ []) do
    attributes =
      Helpers.build_body(
        %{name: opts[:name], space_id: opts[:space_id]},
        [{"name", :name}, {"spaceId", :space_id}]
      )

    Client.post("#{@base_path}/#{app_id}/copy", %{"attributes" => attributes}, Helpers.get_config(opts))
  end

  @doc """
  Gets app metadata including reload time and data model info.

  ## Examples

      iex> QlikElixir.REST.Apps.get_metadata("app-123")
      {:ok, %{"reload_time" => "...", "static_byte_size" => 1024000}}

  """
  @spec get_metadata(String.t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def get_metadata(app_id, opts \\ []) do
    Client.get("#{@base_path}/#{app_id}/data/metadata", Helpers.get_config(opts))
  end

  @doc """
  Gets data lineage information for an app.

  ## Examples

      iex> QlikElixir.REST.Apps.get_lineage("app-123")
      {:ok, %{"data" => [...]}}

  """
  @spec get_lineage(String.t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def get_lineage(app_id, opts \\ []) do
    Client.get("#{@base_path}/#{app_id}/data/lineage", Helpers.get_config(opts))
  end

  # Private helpers

  defp build_attributes_body(params) do
    attributes =
      Helpers.build_body(params, [
        {"name", :name},
        {"description", :description},
        {"spaceId", :space_id}
      ])

    %{"attributes" => attributes}
  end
end
