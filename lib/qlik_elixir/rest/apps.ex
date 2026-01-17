defmodule QlikElixir.REST.Apps do
  @moduledoc """
  Qlik Cloud Apps REST API client.

  Provides functions to manage Qlik Sense applications including
  listing, creating, updating, copying, publishing, and exporting apps.

  ## API Reference

  [Qlik Apps API Documentation](https://qlik.dev/apis/rest/apps/)

  ## Features

  - **CRUD Operations**: List, get, create, update, delete apps
  - **Publishing**: Publish apps to managed spaces
  - **Export/Import**: Export apps as .qvf files and import from binary
  - **Scripts**: Get and validate load scripts
  - **Media**: List media files and get thumbnails
  - **Metadata**: Get app lineage and metadata

  ## Examples

      # List apps
      {:ok, %{"data" => apps}} = QlikElixir.REST.Apps.list(limit: 50)

      # Get app details
      {:ok, app} = QlikElixir.REST.Apps.get("app-id")

      # Publish to managed space
      {:ok, published} = QlikElixir.REST.Apps.publish("app-id", "space-id")

      # Export as .qvf
      {:ok, binary} = QlikElixir.REST.Apps.export("app-id")

  ## Related Modules

  - `QlikElixir.REST.Spaces` - Manage spaces where apps live
  - `QlikElixir.REST.Reloads` - Trigger app data reloads
  - `QlikElixir.QIX.App` - Extract data from app visualizations
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

  @doc """
  Publishes an app to a managed space.

  ## Examples

      iex> QlikElixir.REST.Apps.publish("app-123", "space-456")
      {:ok, %{"id" => "published-app-id"}}

  """
  @spec publish(String.t(), String.t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def publish(app_id, space_id, opts \\ []) do
    Client.post("#{@base_path}/#{app_id}/publish", %{"spaceId" => space_id}, Helpers.get_config(opts))
  end

  @doc """
  Exports an app as a .qvf binary file.

  ## Examples

      iex> QlikElixir.REST.Apps.export("app-123")
      {:ok, <<binary>>}

  """
  @spec export(String.t(), keyword()) :: {:ok, binary()} | {:error, Error.t()}
  def export(app_id, opts \\ []) do
    Client.post("#{@base_path}/#{app_id}/export", %{}, Helpers.get_config(opts))
  end

  @doc """
  Imports an app from a .qvf binary file.

  ## Options

    * `:name` - Custom name for the imported app
    * `:space_id` - Target space for the imported app
    * `:config` - Custom configuration

  ## Examples

      iex> QlikElixir.REST.Apps.import_app(binary_data, name: "My App")
      {:ok, %{"id" => "new-app-id"}}

  """
  @spec import_app(binary(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def import_app(binary, opts \\ []) do
    query = Helpers.build_query(opts, [{:name, :name}, {:spaceId, :space_id}])
    path = Helpers.build_path("#{@base_path}/import", query)

    Client.post_binary(path, binary, "application/octet-stream", Helpers.get_config(opts))
  end

  @doc """
  Gets the load script of an app.

  ## Examples

      iex> QlikElixir.REST.Apps.get_script("app-123")
      {:ok, %{"script" => "LOAD * FROM ..."}}

  """
  @spec get_script(String.t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def get_script(app_id, opts \\ []) do
    Client.get("#{@base_path}/#{app_id}/script", Helpers.get_config(opts))
  end

  @doc """
  Validates a Qlik load script without executing it.

  ## Parameters

    * `script` - The load script to validate

  ## Examples

      iex> QlikElixir.REST.Apps.validate_script("LOAD * FROM data.csv;")
      {:ok, %{"valid" => true}}

  """
  @spec validate_script(String.t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def validate_script(script, opts \\ []) do
    Client.post("#{@base_path}/validatescript", %{"script" => script}, Helpers.get_config(opts))
  end

  @doc """
  Lists media files in an app.

  ## Options

    * `:path` - Optional path within the media folder
    * `:config` - Custom configuration

  ## Examples

      iex> QlikElixir.REST.Apps.list_media("app-123")
      {:ok, %{"data" => [...]}}

      iex> QlikElixir.REST.Apps.list_media("app-123", path: "images")
      {:ok, %{"data" => [...]}}

  """
  @spec list_media(String.t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def list_media(app_id, opts \\ []) do
    path =
      case opts[:path] do
        nil -> "#{@base_path}/#{app_id}/media/list"
        subpath -> "#{@base_path}/#{app_id}/media/list/#{subpath}"
      end

    Client.get(path, Helpers.get_config(opts))
  end

  @doc """
  Gets the thumbnail image of an app.

  ## Examples

      iex> QlikElixir.REST.Apps.get_thumbnail("app-123")
      {:ok, <<binary>>}

  """
  @spec get_thumbnail(String.t(), keyword()) :: {:ok, binary()} | {:error, Error.t()}
  def get_thumbnail(app_id, opts \\ []) do
    Client.get("#{@base_path}/#{app_id}/media/thumbnail", Helpers.get_config(opts))
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
