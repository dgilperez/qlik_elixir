defmodule QlikElixir.REST.Audits do
  @moduledoc """
  REST API client for Qlik Cloud Audits.

  Provides functions to query audit logs for compliance and monitoring.

  ## Examples

      # List recent audit events
      {:ok, %{"data" => events}} = Audits.list(config: config)

      # Filter by event type
      {:ok, %{"data" => events}} = Audits.list(config: config, event_type: "com.qlik.v1.app.created")

      # Get event details
      {:ok, event} = Audits.get("audit-123", config: config)

      # List available sources and types
      {:ok, sources} = Audits.list_sources(config: config)
      {:ok, types} = Audits.list_types(config: config)

  """

  alias QlikElixir.{Client, Error}
  alias QlikElixir.REST.Helpers

  @base_path "api/v1/audits"

  @doc """
  Lists audit events.

  ## Options

    * `:config` - Required. The configuration struct.
    * `:limit` - Maximum number of results per page.
    * `:next` - Cursor for pagination.
    * `:event_type` - Filter by event type (e.g., "com.qlik.v1.app.created").
    * `:user_id` - Filter by user ID.
    * `:source` - Filter by source (e.g., "com.qlik").

  """
  @spec list(keyword()) :: {:ok, map()} | {:error, Error.t()}
  def list(opts \\ []) do
    query =
      Helpers.build_query(opts, [
        {:eventType, :event_type},
        {:userId, :user_id},
        {:source, :source}
      ])

    path = Helpers.build_path(@base_path, query)
    Client.get(path, Helpers.get_config(opts))
  end

  @doc """
  Gets an audit event by ID.
  """
  @spec get(String.t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def get(audit_id, opts \\ []) do
    "#{@base_path}/#{audit_id}"
    |> Client.get(Helpers.get_config(opts))
    |> Helpers.normalize_get_response("Audit event")
  end

  @doc """
  Lists available audit sources.
  """
  @spec list_sources(keyword()) :: {:ok, map()} | {:error, Error.t()}
  def list_sources(opts \\ []) do
    Client.get("#{@base_path}/sources", Helpers.get_config(opts))
  end

  @doc """
  Lists available audit event types.
  """
  @spec list_types(keyword()) :: {:ok, map()} | {:error, Error.t()}
  def list_types(opts \\ []) do
    Client.get("#{@base_path}/types", Helpers.get_config(opts))
  end

  @doc """
  Gets audit settings for the tenant.
  """
  @spec get_settings(keyword()) :: {:ok, map()} | {:error, Error.t()}
  def get_settings(opts \\ []) do
    Client.get("#{@base_path}/settings", Helpers.get_config(opts))
  end
end
