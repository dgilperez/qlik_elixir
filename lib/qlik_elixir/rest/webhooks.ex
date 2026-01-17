defmodule QlikElixir.REST.Webhooks do
  @moduledoc """
  REST API client for Qlik Cloud Webhooks.

  Provides functions to manage webhooks for event notifications.

  ## Examples

      # List all webhooks
      {:ok, %{"data" => webhooks}} = Webhooks.list(config: config)

      # Create a webhook
      params = %{
        name: "Reload Notifications",
        url: "https://example.com/webhook",
        eventTypes: ["com.qlik.v1.reload.finished"]
      }
      {:ok, webhook} = Webhooks.create(params, config: config)

      # List available event types
      {:ok, %{"data" => types}} = Webhooks.list_event_types(config: config)

      # List deliveries
      {:ok, %{"data" => deliveries}} = Webhooks.list_deliveries("hook-123", config: config)

  """

  alias QlikElixir.{Client, Error}
  alias QlikElixir.REST.Helpers

  @base_path "api/v1/webhooks"

  @doc """
  Lists all webhooks.

  ## Options

    * `:config` - Required. The configuration struct.
    * `:limit` - Maximum number of results per page.
    * `:next` - Cursor for pagination.
    * `:name` - Filter by name (partial match).
    * `:enabled` - Filter by enabled status.

  """
  @spec list(keyword()) :: {:ok, map()} | {:error, Error.t()}
  def list(opts \\ []) do
    query = Helpers.build_query(opts, [{:name, :name}, {:enabled, :enabled}])
    path = Helpers.build_path(@base_path, query)
    Client.get(path, Helpers.get_config(opts))
  end

  @doc """
  Gets a webhook by ID.
  """
  @spec get(String.t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def get(webhook_id, opts \\ []) do
    "#{@base_path}/#{webhook_id}"
    |> Client.get(Helpers.get_config(opts))
    |> Helpers.normalize_get_response("Webhook")
  end

  @doc """
  Creates a new webhook.

  ## Parameters

    * `params` - Map with webhook details:
      * `:name` - Required. Webhook name.
      * `:url` - Required. Target URL for webhook deliveries.
      * `:eventTypes` - Required. List of event type strings.
      * `:enabled` - Optional. Whether webhook is enabled (default: true).
      * `:secret` - Optional. Shared secret for signature verification.

  """
  @spec create(map(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def create(params, opts \\ []) do
    body = Helpers.build_body(params, [:name, :url, :eventTypes, :enabled, :secret, :headers])
    Client.post(@base_path, body, Helpers.get_config(opts))
  end

  @doc """
  Updates a webhook.

  ## Parameters

    * `webhook_id` - The webhook ID.
    * `params` - Map with fields to update.

  """
  @spec update(String.t(), map(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def update(webhook_id, params, opts \\ []) do
    path = "#{@base_path}/#{webhook_id}"
    body = Helpers.build_body(params, [:name, :url, :eventTypes, :enabled, :secret, :headers])
    Client.patch(path, body, Helpers.get_config(opts))
  end

  @doc """
  Deletes a webhook.
  """
  @spec delete(String.t(), keyword()) :: :ok | {:error, Error.t()}
  def delete(webhook_id, opts \\ []) do
    "#{@base_path}/#{webhook_id}"
    |> Client.delete(Helpers.get_config(opts))
    |> Helpers.normalize_delete_response("Webhook")
  end

  @doc """
  Lists available webhook event types.
  """
  @spec list_event_types(keyword()) :: {:ok, map()} | {:error, Error.t()}
  def list_event_types(opts \\ []) do
    path = "#{@base_path}/event-types"
    Client.get(path, Helpers.get_config(opts))
  end

  # Deliveries

  @doc """
  Lists deliveries for a webhook.

  ## Options

    * `:limit` - Maximum number of results per page.
    * `:next` - Cursor for pagination.
    * `:status` - Filter by delivery status ("success", "failed", "pending").

  """
  @spec list_deliveries(String.t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def list_deliveries(webhook_id, opts \\ []) do
    query = Helpers.build_query(opts, [{:status, :status}])
    path = Helpers.build_path("#{@base_path}/#{webhook_id}/deliveries", query)
    Client.get(path, Helpers.get_config(opts))
  end

  @doc """
  Gets details of a specific delivery.

  ## Parameters

    * `webhook_id` - The webhook ID.
    * `delivery_id` - The delivery ID.

  """
  @spec get_delivery(String.t(), String.t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def get_delivery(webhook_id, delivery_id, opts \\ []) do
    path = "#{@base_path}/#{webhook_id}/deliveries/#{delivery_id}"
    Client.get(path, Helpers.get_config(opts))
  end

  @doc """
  Resends a failed delivery.

  ## Parameters

    * `webhook_id` - The webhook ID.
    * `delivery_id` - The delivery ID to resend.

  """
  @spec resend_delivery(String.t(), String.t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def resend_delivery(webhook_id, delivery_id, opts \\ []) do
    path = "#{@base_path}/#{webhook_id}/deliveries/#{delivery_id}/actions/resend"
    Client.post(path, %{}, Helpers.get_config(opts))
  end
end
