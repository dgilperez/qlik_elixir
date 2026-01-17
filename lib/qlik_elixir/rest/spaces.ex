defmodule QlikElixir.REST.Spaces do
  @moduledoc """
  Qlik Cloud Spaces REST API client.

  Provides functions to manage spaces including listing, creating,
  updating, deleting spaces, and managing space assignments.

  API Reference: https://qlik.dev/apis/rest/spaces/
  """

  alias QlikElixir.{Client, Error}
  alias QlikElixir.REST.Helpers

  @base_path "api/v1/spaces"

  @doc """
  Lists spaces accessible to the current user.

  ## Options

    * `:limit` - Maximum number of spaces to return
    * `:next` - Cursor for pagination
    * `:type` - Filter by space type (shared, managed, data)
    * `:config` - Custom configuration

  ## Examples

      iex> QlikElixir.REST.Spaces.list(type: "shared")
      {:ok, %{"data" => [...]}}

  """
  @spec list(keyword()) :: {:ok, map()} | {:error, Error.t()}
  def list(opts \\ []) do
    query = Helpers.build_query(opts, [{:type, :type}])
    path = Helpers.build_path(@base_path, query)

    Client.get(path, Helpers.get_config(opts))
  end

  @doc """
  Gets details for a specific space.

  ## Examples

      iex> QlikElixir.REST.Spaces.get("space-123")
      {:ok, %{"id" => "space-123", "name" => "My Space"}}

  """
  @spec get(String.t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def get(space_id, opts \\ []) do
    "#{@base_path}/#{space_id}"
    |> Client.get(Helpers.get_config(opts))
    |> Helpers.normalize_get_response("Space")
  end

  @doc """
  Creates a new space.

  ## Parameters

    * `params` - Map with space attributes:
      * `:name` - Space name (required)
      * `:type` - Space type (shared, managed, data)
      * `:description` - Space description

  ## Examples

      iex> QlikElixir.REST.Spaces.create(%{name: "Dev Space", type: "shared"})
      {:ok, %{"id" => "new-id", "name" => "Dev Space"}}

  """
  @spec create(map(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def create(params, opts \\ []) do
    body =
      Helpers.build_body(params, [
        {"name", :name},
        {"type", :type},
        {"description", :description}
      ])

    Client.post(@base_path, body, Helpers.get_config(opts))
  end

  @doc """
  Updates an existing space using JSON Patch format.

  ## Examples

      iex> QlikElixir.REST.Spaces.update("space-123", %{description: "Updated"})
      {:ok, %{"id" => "space-123", "description" => "Updated"}}

  """
  @spec update(String.t(), map(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def update(space_id, params, opts \\ []) do
    # Qlik Spaces API uses JSON Patch format
    body =
      params
      |> Enum.map(fn
        {:name, value} -> %{"op" => "replace", "path" => "/name", "value" => value}
        {:description, value} -> %{"op" => "replace", "path" => "/description", "value" => value}
        {key, value} when is_atom(key) -> %{"op" => "replace", "path" => "/#{key}", "value" => value}
        {key, value} -> %{"op" => "replace", "path" => "/#{key}", "value" => value}
      end)

    Client.patch("#{@base_path}/#{space_id}", body, Helpers.get_config(opts))
  end

  @doc """
  Deletes a space.

  ## Examples

      iex> QlikElixir.REST.Spaces.delete("space-123")
      :ok

  """
  @spec delete(String.t(), keyword()) :: :ok | {:error, Error.t()}
  def delete(space_id, opts \\ []) do
    "#{@base_path}/#{space_id}"
    |> Client.delete(Helpers.get_config(opts))
    |> Helpers.normalize_delete_response("Space")
  end

  @doc """
  Lists assignments for a space.

  ## Examples

      iex> QlikElixir.REST.Spaces.list_assignments("space-123")
      {:ok, %{"data" => [...]}}

  """
  @spec list_assignments(String.t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def list_assignments(space_id, opts \\ []) do
    Client.get("#{@base_path}/#{space_id}/assignments", Helpers.get_config(opts))
  end

  @doc """
  Creates an assignment (adds a user or group to a space).

  ## Parameters

    * `space_id` - The space ID
    * `params` - Map with assignment attributes:
      * `:type` - Assignment type (user, group)
      * `:assignee_id` - User or group ID
      * `:roles` - List of roles (consumer, contributor, producer, etc.)

  ## Examples

      iex> QlikElixir.REST.Spaces.create_assignment("space-123", %{type: "user", assignee_id: "user-456", roles: ["consumer"]})
      {:ok, %{"id" => "assign-id"}}

  """
  @spec create_assignment(String.t(), map(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def create_assignment(space_id, params, opts \\ []) do
    body =
      Helpers.build_body(params, [
        {"type", :type},
        {"assigneeId", :assignee_id},
        {"roles", :roles}
      ])

    Client.post("#{@base_path}/#{space_id}/assignments", body, Helpers.get_config(opts))
  end

  @doc """
  Deletes an assignment from a space.

  ## Examples

      iex> QlikElixir.REST.Spaces.delete_assignment("space-123", "assign-456")
      :ok

  """
  @spec delete_assignment(String.t(), String.t(), keyword()) :: :ok | {:error, Error.t()}
  def delete_assignment(space_id, assignment_id, opts \\ []) do
    "#{@base_path}/#{space_id}/assignments/#{assignment_id}"
    |> Client.delete(Helpers.get_config(opts))
    |> Helpers.normalize_delete_response("Assignment")
  end

  @doc """
  Lists available space types.

  ## Examples

      iex> QlikElixir.REST.Spaces.list_types()
      {:ok, %{"data" => [%{"name" => "shared"}, %{"name" => "managed"}]}}

  """
  @spec list_types(keyword()) :: {:ok, map()} | {:error, Error.t()}
  def list_types(opts \\ []) do
    Client.get("#{@base_path}/types", Helpers.get_config(opts))
  end
end
