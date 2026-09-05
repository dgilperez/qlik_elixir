defmodule QlikElixir.REST.Reports do
  @moduledoc """
  Qlik Cloud Reporting API client.

  The Reporting API is asynchronous and has exactly three operations: you queue a
  request, you poll its status, and you list the outputs it produced. There is no
  listing of past reports and no way to delete or fetch one by id — a report
  request is a job, not a stored resource.

      POST /api/v1/reports              -> 202 {requestId, outputsUrl, message}
      GET  /api/v1/reports/{id}/status  -> 200 {status, ...}
      GET  /api/v1/reports/{id}/outputs -> 200 {data: [{outputId, location, sizeBytes, status}]}

  The generated file lives in temporary content and is fetched from the `location`
  returned with each output. It expires after `meta.outputTtl` (one hour by default).

  ## Queueing a report

  The request body is passed through untouched, so any template type documented at
  https://qlik.dev/apis/rest/reports/ works. This exports a Sense sheet to PDF:

      request = %{
        type: "sense-sheet-1.0",
        senseSheetTemplate: %{
          appId: "app-123",
          sheet: %{id: "sheet-456"}
        },
        output: %{
          type: "pdf",
          outputId: "monthly-sales",
          pdfOutput: %{size: "A4", orientation: "L", resizeType: "autofit"}
        },
        meta: %{outputTtl: "PT10M"}
      }

      {:ok, %{"requestId" => id}} = Reports.create(request, config: config)

  ## Waiting for it

  `generate/2` does the whole round trip — queue, poll, list outputs:

      {:ok, [output]} = Reports.generate(request, config: config)
      {:ok, pdf} = Reports.download_output(output, config: config)
      File.write!("monthly-sales.pdf", pdf)

  The pieces are also available on their own (`create/2`, `await/2`,
  `list_outputs/2`) when you want to queue now and collect later.

  API reference: https://qlik.dev/apis/rest/reports/
  """

  alias QlikElixir.{Client, Error}
  alias QlikElixir.REST.Helpers

  @base_path "api/v1/reports"

  @terminal_statuses ~w(done failed aborted)
  @failed_statuses ~w(failed aborted)

  @default_poll_interval 2_000
  @default_timeout 300_000

  @doc """
  Queues a report request.

  `request` is the report definition described in the module docs; it is sent as-is.
  Qlik answers `202 Accepted` with the request id and the URL of its outputs.

  Rate limited by Qlik to 10 requests per minute.

  ## Examples

      iex> QlikElixir.REST.Reports.create(request, config: config)
      {:ok, %{"requestId" => "7d6bc2ee-...", "outputsUrl" => "https://...", "message" => "..."}}

  """
  @spec create(map(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def create(request, opts \\ []) do
    Client.post(@base_path, request, Helpers.get_config(opts))
  end

  @doc """
  Gets the processing status of a report request.

  `status` is one of `"queued"`, `"processing"`, `"visiting"`, `"aborting"`,
  `"done"`, `"failed"` or `"aborted"`.

  ## Examples

      iex> QlikElixir.REST.Reports.get_status("7d6bc2ee-...", config: config)
      {:ok, %{"status" => "done", "resolutionAttempts" => 1, ...}}

  """
  @spec get_status(String.t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def get_status(request_id, opts \\ []) do
    "#{@base_path}/#{request_id}/status"
    |> Client.get(Helpers.get_config(opts))
    |> Helpers.normalize_get_response("Report request")
  end

  @doc """
  Lists the outputs produced so far for a report request.

  Outputs are generated asynchronously, so the list is only complete once the
  request has reached a terminal status.

  ## Options

    * `:filter` - SCIM filter, `eq` on `outputId` (e.g. `~s(outputId eq "cover")`)
    * `:limit` - Page size
    * `:page` - Cursor for the page to return
    * `:sort` - `"+outputId"`, `"-outputId"`, `"+sizeBytes"`, `"-sizeBytes"`, or a
      list of them
    * `:config` - Custom configuration

  ## Examples

      iex> QlikElixir.REST.Reports.list_outputs("7d6bc2ee-...", config: config)
      {:ok, %{"data" => [%{"outputId" => "monthly-sales", "location" => "https://...", "sizeBytes" => 484_927, "status" => "done"}], "links" => %{}}}

  """
  @spec list_outputs(String.t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def list_outputs(request_id, opts \\ []) do
    query =
      Helpers.build_query(
        opts,
        [{:filter, :filter}, {:page, :page}, {:sort, :sort}],
        [{:limit, :limit}]
      )

    "#{@base_path}/#{request_id}/outputs"
    |> Helpers.build_path(query)
    |> Client.get(Helpers.get_config(opts))
    |> Helpers.normalize_get_response("Report request")
  end

  @doc """
  Polls a report request until it reaches a terminal status.

  Returns the final status map when the report is `done`. A `failed` or `aborted`
  report is an error, as is running out of time.

  ## Options

    * `:interval` - Milliseconds between polls (default: 2000)
    * `:timeout` - Milliseconds to wait before giving up (default: 300_000).
      Qlik's own export deadline defaults to 10 minutes and caps at 4 hours; set
      this above `meta.exportDeadline` if you raised it.
    * `:config` - Custom configuration

  ## Examples

      iex> QlikElixir.REST.Reports.await("7d6bc2ee-...", config: config)
      {:ok, %{"status" => "done", ...}}

  """
  @spec await(String.t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def await(request_id, opts \\ []) do
    interval = Keyword.get(opts, :interval, @default_poll_interval)
    timeout = Keyword.get(opts, :timeout, @default_timeout)

    with :ok <- validate_millis(:interval, interval),
         :ok <- validate_millis(:timeout, timeout) do
      budget = %{
        interval: interval,
        timeout: timeout,
        deadline: System.monotonic_time(:millisecond) + timeout
      }

      poll(request_id, opts, budget)
    end
  end

  @doc """
  Queues a report, waits for it and returns its outputs.

  Equivalent to `create/2`, then `await/2`, then `list_outputs/2`. Accepts the
  options of all three.

  Outputs expire with the request's `outputTtl`. To be able to collect them again
  later, drive the three calls yourself and keep the `requestId` that `create/2`
  returns.

  ## Examples

      iex> {:ok, [output]} = QlikElixir.REST.Reports.generate(request, config: config)
      iex> output["outputId"]
      "monthly-sales"

  """
  @spec generate(map(), keyword()) :: {:ok, list(map())} | {:error, Error.t()}
  def generate(request, opts \\ []) do
    with {:ok, %{"requestId" => request_id}} <- create(request, opts),
         {:ok, _status} <- await(request_id, opts),
         {:ok, %{"data" => outputs}} <- list_outputs(request_id, opts) do
      {:ok, outputs}
    else
      {:ok, %{} = response} ->
        {:error, Error.unknown_error("Unexpected response from Reporting API", details: response)}

      {:error, _} = error ->
        error
    end
  end

  @doc """
  Downloads a generated report file.

  Takes either an output map from `list_outputs/2` or its `location` URL, and
  returns the raw file. The location points at temporary content that expires with
  the request's `outputTtl`.

  ## Examples

      iex> {:ok, pdf} = QlikElixir.REST.Reports.download_output(output, config: config)
      iex> File.write!("report.pdf", pdf)

  """
  @spec download_output(map() | String.t(), keyword()) :: {:ok, binary()} | {:error, Error.t()}
  def download_output(output_or_location, opts \\ [])

  def download_output(%{"location" => location}, opts), do: download_output(location, opts)

  def download_output(location, opts) when is_binary(location) do
    location
    |> content_path()
    |> Client.get(Helpers.get_config(opts), decode_body: false)
    |> Helpers.normalize_get_response("Report output")
  end

  def download_output(output, _opts) when is_map(output) do
    {:error, Error.validation_error("Output has no location; the report may not be done yet")}
  end

  defp validate_millis(_key, value) when is_integer(value) and value >= 0, do: :ok

  defp validate_millis(key, value) do
    {:error, Error.validation_error(":#{key} must be a non-negative integer of milliseconds, got #{inspect(value)}")}
  end

  defp poll(request_id, opts, budget) do
    case get_status(request_id, opts) do
      {:ok, %{"status" => status} = payload} when status in @failed_statuses ->
        {:error, Error.report_failed("Report request #{status}", details: payload)}

      {:ok, %{"status" => status} = payload} when status in @terminal_statuses ->
        {:ok, payload}

      {:ok, _pending} ->
        wait_and_retry(request_id, opts, budget)

      {:error, _} = error ->
        error
    end
  end

  defp wait_and_retry(request_id, opts, %{interval: interval, deadline: deadline} = budget) do
    if System.monotonic_time(:millisecond) + interval >= deadline do
      {:error, Error.timeout_error("Report #{request_id} not finished after #{budget.timeout}ms")}
    else
      Process.sleep(interval)
      poll(request_id, opts, budget)
    end
  end

  # Qlik returns absolute locations including the port (https://tenant:443/api/v1/...).
  # Only the path travels: Client rebuilds the URL from the configured tenant, so a
  # host in an API response can never send the bearer token somewhere else.
  defp content_path(location) do
    uri = URI.parse(location)
    path = String.trim_leading(uri.path || location, "/")

    if uri.query, do: "#{path}?#{uri.query}", else: path
  end
end
