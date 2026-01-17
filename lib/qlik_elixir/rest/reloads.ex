defmodule QlikElixir.REST.Reloads do
  @moduledoc """
  Qlik Cloud Reloads REST API client.

  Provides functions to trigger and manage app reloads.

  API Reference: https://qlik.dev/apis/rest/reloads/
  """

  alias QlikElixir.{Client, Error}
  alias QlikElixir.REST.Helpers

  @base_path "api/v1/reloads"

  @doc """
  Lists reloads.

  ## Options

    * `:app_id` - Filter by app ID
    * `:status` - Filter by status (QUEUED, RELOADING, SUCCEEDED, FAILED, CANCELING, CANCELED)
    * `:limit` - Maximum number of reloads to return
    * `:next` - Cursor for pagination
    * `:config` - Custom configuration

  ## Examples

      iex> QlikElixir.REST.Reloads.list(app_id: "app-123")
      {:ok, %{"data" => [...]}}

  """
  @spec list(keyword()) :: {:ok, map()} | {:error, Error.t()}
  def list(opts \\ []) do
    query = Helpers.build_query(opts, [{:appId, :app_id}, {:status, :status}])
    path = Helpers.build_path(@base_path, query)

    Client.get(path, Helpers.get_config(opts))
  end

  @doc """
  Gets details for a specific reload.

  ## Examples

      iex> QlikElixir.REST.Reloads.get("reload-123")
      {:ok, %{"id" => "reload-123", "status" => "SUCCEEDED"}}

  """
  @spec get(String.t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def get(reload_id, opts \\ []) do
    "#{@base_path}/#{reload_id}"
    |> Client.get(Helpers.get_config(opts))
    |> Helpers.normalize_get_response("Reload")
  end

  @doc """
  Creates a new reload for an app.

  ## Options

    * `:partial` - Whether to perform a partial reload (default: false)
    * `:config` - Custom configuration

  ## Examples

      iex> QlikElixir.REST.Reloads.create("app-123")
      {:ok, %{"id" => "reload-new", "status" => "QUEUED"}}

      iex> QlikElixir.REST.Reloads.create("app-123", partial: true)
      {:ok, %{"id" => "reload-new", "status" => "QUEUED"}}

  """
  @spec create(String.t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def create(app_id, opts \\ []) do
    body = build_create_body(app_id, opts)
    Client.post(@base_path, body, Helpers.get_config(opts))
  end

  @doc """
  Cancels a queued or running reload.

  ## Examples

      iex> QlikElixir.REST.Reloads.cancel("reload-123")
      {:ok, %{"id" => "reload-123", "status" => "CANCELING"}}

  """
  @spec cancel(String.t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def cancel(reload_id, opts \\ []) do
    Client.post("#{@base_path}/#{reload_id}/actions/cancel", %{}, Helpers.get_config(opts))
  end

  defp build_create_body(app_id, opts) do
    %{"appId" => app_id}
    |> Helpers.put_if_present("partial", opts[:partial])
  end
end
