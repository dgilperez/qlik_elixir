defmodule QlikElixir.REST.Automations do
  @moduledoc """
  REST API client for Qlik Cloud Automations.

  Provides functions to manage automations (no-code workflows) including
  creating, running, and monitoring automation executions.

  ## Examples

      # List all automations
      {:ok, %{"data" => automations}} = Automations.list(config: config)

      # Get automation details
      {:ok, automation} = Automations.get("auto-123", config: config)

      # Enable/disable an automation
      {:ok, automation} = Automations.enable("auto-123", config: config)
      {:ok, automation} = Automations.disable("auto-123", config: config)

      # Trigger a run
      {:ok, run} = Automations.run("auto-123", config: config)

      # List runs
      {:ok, %{"data" => runs}} = Automations.list_runs("auto-123", config: config)

  """

  alias QlikElixir.{Client, Error}
  alias QlikElixir.REST.Helpers

  @base_path "api/v1/automations"

  @doc """
  Lists all automations.

  ## Options

    * `:config` - Required. The configuration struct.
    * `:limit` - Maximum number of results per page.
    * `:next` - Cursor for pagination.
    * `:name` - Filter by name (partial match).
    * `:state` - Filter by state ("enabled", "disabled").

  """
  @spec list(keyword()) :: {:ok, map()} | {:error, Error.t()}
  def list(opts \\ []) do
    query = Helpers.build_query(opts, [{:name, :name}, {:state, :state}])
    path = Helpers.build_path(@base_path, query)
    Client.get(path, Helpers.get_config(opts))
  end

  @doc """
  Gets an automation by ID.
  """
  @spec get(String.t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def get(automation_id, opts \\ []) do
    "#{@base_path}/#{automation_id}"
    |> Client.get(Helpers.get_config(opts))
    |> Helpers.normalize_get_response("Automation")
  end

  @doc """
  Creates a new automation.

  ## Parameters

    * `params` - Map with automation details:
      * `:name` - Required. Automation name.
      * `:workspace` - Required. Automation workspace definition.

  """
  @spec create(map(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def create(params, opts \\ []) do
    body = Helpers.build_body(params, [:name, :workspace, :description, :spaceId])
    Client.post(@base_path, body, Helpers.get_config(opts))
  end

  @doc """
  Updates an automation.

  Note: Uses PUT for full replacement of the automation.

  ## Parameters

    * `automation_id` - The automation ID.
    * `params` - Map with automation details.

  """
  @spec update(String.t(), map(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def update(automation_id, params, opts \\ []) do
    path = "#{@base_path}/#{automation_id}"
    body = Helpers.build_body(params, [:name, :workspace, :description, :state])
    Client.put(path, body, Helpers.get_config(opts))
  end

  @doc """
  Deletes an automation.
  """
  @spec delete(String.t(), keyword()) :: :ok | {:error, Error.t()}
  def delete(automation_id, opts \\ []) do
    "#{@base_path}/#{automation_id}"
    |> Client.delete(Helpers.get_config(opts))
    |> Helpers.normalize_delete_response("Automation")
  end

  @doc """
  Enables an automation.
  """
  @spec enable(String.t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def enable(automation_id, opts \\ []) do
    path = "#{@base_path}/#{automation_id}/actions/enable"
    Client.post(path, %{}, Helpers.get_config(opts))
  end

  @doc """
  Disables an automation.
  """
  @spec disable(String.t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def disable(automation_id, opts \\ []) do
    path = "#{@base_path}/#{automation_id}/actions/disable"
    Client.post(path, %{}, Helpers.get_config(opts))
  end

  @doc """
  Copies an automation.
  """
  @spec copy(String.t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def copy(automation_id, opts \\ []) do
    path = "#{@base_path}/#{automation_id}/actions/copy"
    Client.post(path, %{}, Helpers.get_config(opts))
  end

  @doc """
  Changes the owner of an automation.

  ## Parameters

    * `automation_id` - The automation ID.
    * `owner_id` - The new owner's user ID.

  """
  @spec change_owner(String.t(), String.t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def change_owner(automation_id, owner_id, opts \\ []) do
    path = "#{@base_path}/#{automation_id}/actions/change-owner"
    body = %{"ownerId" => owner_id}
    Client.post(path, body, Helpers.get_config(opts))
  end

  @doc """
  Moves an automation to another space.

  ## Parameters

    * `automation_id` - The automation ID.
    * `space_id` - The target space ID.

  """
  @spec change_space(String.t(), String.t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def change_space(automation_id, space_id, opts \\ []) do
    path = "#{@base_path}/#{automation_id}/actions/change-space"
    body = %{"spaceId" => space_id}
    Client.post(path, body, Helpers.get_config(opts))
  end

  # Runs

  @doc """
  Lists runs for an automation.

  ## Options

    * `:limit` - Maximum number of results per page.
    * `:next` - Cursor for pagination.
    * `:status` - Filter by status.

  """
  @spec list_runs(String.t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def list_runs(automation_id, opts \\ []) do
    query = Helpers.build_query(opts, [{:status, :status}])
    path = Helpers.build_path("#{@base_path}/#{automation_id}/runs", query)
    Client.get(path, Helpers.get_config(opts))
  end

  @doc """
  Triggers an automation run.

  ## Options

    * `:inputs` - Map of input parameters for the automation.

  """
  @spec run(String.t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def run(automation_id, opts \\ []) do
    path = "#{@base_path}/#{automation_id}/actions/run"

    body =
      case Keyword.get(opts, :inputs) do
        nil -> %{}
        inputs -> %{"inputs" => inputs}
      end

    Client.post(path, body, Helpers.get_config(opts))
  end

  @doc """
  Gets details of a specific run.

  ## Parameters

    * `automation_id` - The automation ID.
    * `run_id` - The run ID.

  """
  @spec get_run(String.t(), String.t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def get_run(automation_id, run_id, opts \\ []) do
    path = "#{@base_path}/#{automation_id}/runs/#{run_id}"
    Client.get(path, Helpers.get_config(opts))
  end

  @doc """
  Stops a running automation.

  ## Parameters

    * `automation_id` - The automation ID.
    * `run_id` - The run ID.

  """
  @spec stop_run(String.t(), String.t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def stop_run(automation_id, run_id, opts \\ []) do
    path = "#{@base_path}/#{automation_id}/runs/#{run_id}/actions/stop"
    Client.post(path, %{}, Helpers.get_config(opts))
  end

  @doc """
  Retries a failed run.

  ## Parameters

    * `automation_id` - The automation ID.
    * `run_id` - The run ID to retry.

  """
  @spec retry_run(String.t(), String.t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def retry_run(automation_id, run_id, opts \\ []) do
    path = "#{@base_path}/#{automation_id}/runs/#{run_id}/actions/retry"
    Client.post(path, %{}, Helpers.get_config(opts))
  end

  @doc """
  Gets automation usage statistics.
  """
  @spec get_usage(keyword()) :: {:ok, map()} | {:error, Error.t()}
  def get_usage(opts \\ []) do
    path = "#{@base_path}/usage"
    Client.get(path, Helpers.get_config(opts))
  end
end
