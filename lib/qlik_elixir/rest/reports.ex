defmodule QlikElixir.REST.Reports do
  @moduledoc """
  REST API client for Qlik Cloud Reports.

  Reports allow generating and managing report outputs from Qlik apps,
  including Excel templates and PDF exports.

  ## Examples

      # List all reports
      {:ok, %{"data" => reports}} = Reports.list(config: config)

      # Filter by status
      {:ok, %{"data" => completed}} = Reports.list(config: config, status: "completed")

      # Create a report
      {:ok, report} = Reports.create(%{appId: "app-123", type: "sense-excel-template"}, config: config)

      # Download a completed report
      {:ok, %{"url" => url}} = Reports.download("report-123", config: config)

  """

  alias QlikElixir.{Client, Error}
  alias QlikElixir.REST.Helpers

  @base_path "api/v1/reports"

  @doc """
  Lists all reports.

  ## Options

    * `:config` - Required. The configuration struct.
    * `:limit` - Maximum number of results per page.
    * `:next` - Cursor for pagination.
    * `:app_id` - Filter by app ID.
    * `:status` - Filter by status ("queued", "processing", "completed", "failed").

  """
  @spec list(keyword()) :: {:ok, map()} | {:error, Error.t()}
  def list(opts \\ []) do
    query =
      Helpers.build_query(opts, [
        {:appId, :app_id},
        {:status, :status}
      ])

    path = Helpers.build_path(@base_path, query)
    Client.get(path, Helpers.get_config(opts))
  end

  @doc """
  Gets a report by ID.
  """
  @spec get(String.t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def get(report_id, opts \\ []) do
    "#{@base_path}/#{report_id}"
    |> Client.get(Helpers.get_config(opts))
    |> Helpers.normalize_get_response("Report")
  end

  @doc """
  Creates a new report.

  ## Parameters

    * `params` - Map with report details:
      * `:appId` - Required. The app ID to generate report from.
      * `:type` - Report type (e.g., "sense-excel-template").
      * `:output` - Output configuration map.

  """
  @spec create(map(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def create(params, opts \\ []) do
    Client.post(@base_path, params, Helpers.get_config(opts))
  end

  @doc """
  Deletes a report.
  """
  @spec delete(String.t(), keyword()) :: :ok | {:error, Error.t()}
  def delete(report_id, opts \\ []) do
    "#{@base_path}/#{report_id}"
    |> Client.delete(Helpers.get_config(opts))
    |> Helpers.normalize_delete_response("Report")
  end

  @doc """
  Gets the download URL for a completed report.

  Returns a temporary URL that can be used to download the report file.
  """
  @spec download(String.t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def download(report_id, opts \\ []) do
    "#{@base_path}/#{report_id}/download"
    |> Client.get(Helpers.get_config(opts))
    |> Helpers.normalize_get_response("Report")
  end

  @doc """
  Gets the status of a report generation.

  Returns progress information for reports still being processed.
  """
  @spec get_status(String.t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def get_status(report_id, opts \\ []) do
    path = "#{@base_path}/#{report_id}/status"
    Client.get(path, Helpers.get_config(opts))
  end
end
