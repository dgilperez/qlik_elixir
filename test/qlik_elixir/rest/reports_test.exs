defmodule QlikElixir.REST.ReportsTest do
  use ExUnit.Case, async: true

  alias QlikElixir.{Config, Error}
  alias QlikElixir.REST.Reports

  setup do
    bypass = Bypass.open()
    config = Config.new(api_key: "test-key", tenant_url: "http://localhost:#{bypass.port}")
    {:ok, bypass: bypass, config: config}
  end

  # The payload Qlik actually accepts, captured from a live tenant.
  defp request do
    %{
      type: "sense-sheet-1.0",
      senseSheetTemplate: %{appId: "app-123", sheet: %{id: "sheet-456"}},
      output: %{
        type: "pdf",
        outputId: "cover",
        pdfOutput: %{size: "A4", orientation: "L", resizeType: "autofit"}
      }
    }
  end

  defp json(conn, status, body) do
    conn
    |> Plug.Conn.put_resp_content_type("application/json")
    |> Plug.Conn.resp(status, Jason.encode!(body))
  end

  defp expect_status(bypass, id, statuses) do
    {:ok, agent} = Agent.start_link(fn -> statuses end)

    Bypass.expect(bypass, "GET", "/api/v1/reports/#{id}/status", fn conn ->
      status = Agent.get_and_update(agent, fn [head | rest] -> {head, if(rest == [], do: [head], else: rest)} end)
      json(conn, 200, %{"status" => status, "statusLocation" => "/reports/#{id}/status"})
    end)
  end

  describe "create/2" do
    test "queues a report request and returns 202 payload", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "POST", "/api/v1/reports", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)

        assert params["type"] == "sense-sheet-1.0"
        assert params["senseSheetTemplate"]["sheet"]["id"] == "sheet-456"
        assert params["output"]["outputId"] == "cover"

        json(conn, 202, %{
          "message" => "Report request has been accepted and is being processed.",
          "outputsUrl" => "https://tenant:443/api/v1/reports/req-1/outputs",
          "requestId" => "req-1"
        })
      end)

      assert {:ok, response} = Reports.create(request(), config: config)
      assert response["requestId"] == "req-1"
    end

    test "surfaces a rejected request body", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "POST", "/api/v1/reports", fn conn ->
        json(conn, 400, %{"message" => "output.outputId is required"})
      end)

      assert {:error, %Error{message: "output.outputId is required"}} = Reports.create(%{}, config: config)
    end
  end

  describe "get_status/2" do
    test "returns the processing status", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/reports/req-1/status", fn conn ->
        json(conn, 200, %{"status" => "processing", "resolutionAttempts" => 1})
      end)

      assert {:ok, %{"status" => "processing"}} = Reports.get_status("req-1", config: config)
    end

    test "returns not_found for an unknown request", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/reports/nope/status", fn conn ->
        json(conn, 404, %{"error" => "Not found"})
      end)

      assert {:error, %Error{type: :not_found}} = Reports.get_status("nope", config: config)
    end
  end

  describe "list_outputs/2" do
    test "returns the produced outputs", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/reports/req-1/outputs", fn conn ->
        json(conn, 200, %{
          "data" => [
            %{
              "outputId" => "cover",
              "location" => "https://tenant:443/api/v1/temp-contents/abc123",
              "sizeBytes" => 484_927,
              "status" => "done"
            }
          ],
          "links" => %{}
        })
      end)

      assert {:ok, %{"data" => [output]}} = Reports.list_outputs("req-1", config: config)
      assert output["sizeBytes"] == 484_927
    end

    test "sends filter, limit, page and sort", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/reports/req-1/outputs", fn conn ->
        query = URI.decode_query(conn.query_string)

        assert query["filter"] == ~s(outputId eq "cover")
        assert query["limit"] == "10"
        assert query["page"] == "1"
        assert query["sort"] == "+outputId,-sizeBytes"

        json(conn, 200, %{"data" => [], "links" => %{}})
      end)

      assert {:ok, _} =
               Reports.list_outputs("req-1",
                 config: config,
                 filter: ~s(outputId eq "cover"),
                 limit: 10,
                 page: "1",
                 sort: ["+outputId", "-sizeBytes"]
               )
    end
  end

  describe "await/2" do
    test "polls until the request is done", %{bypass: bypass, config: config} do
      expect_status(bypass, "req-1", ["queued", "processing", "done"])

      assert {:ok, %{"status" => "done"}} = Reports.await("req-1", config: config, interval: 1)
    end

    test "returns report_failed when Qlik gives up", %{bypass: bypass, config: config} do
      expect_status(bypass, "req-1", ["processing", "failed"])

      assert {:error, %Error{type: :report_failed, message: "Report request failed"}} =
               Reports.await("req-1", config: config, interval: 1)
    end

    test "treats aborted as a failure", %{bypass: bypass, config: config} do
      expect_status(bypass, "req-1", ["aborted"])

      assert {:error, %Error{type: :report_failed}} = Reports.await("req-1", config: config, interval: 1)
    end

    test "gives up once the timeout is spent", %{bypass: bypass, config: config} do
      expect_status(bypass, "req-1", ["processing"])

      # One poll always happens; with no room left for another sleep it gives up.
      assert {:error, %Error{type: :timeout, message: message}} =
               Reports.await("req-1", config: config, interval: 50, timeout: 0)

      assert message =~ "not finished after 0ms"
    end

    test "rejects a nonsensical interval instead of crashing in Process.sleep", %{config: config} do
      assert {:error, %Error{type: :validation_error, message: message}} =
               Reports.await("req-1", config: config, interval: -1)

      assert message =~ ":interval"
    end

    test "rejects a nonsensical timeout", %{config: config} do
      assert {:error, %Error{type: :validation_error, message: message}} =
               Reports.await("req-1", config: config, timeout: "soon")

      assert message =~ ":timeout"
    end

    test "keeps polling while the status is aborting", %{bypass: bypass, config: config} do
      expect_status(bypass, "req-1", ["aborting", "aborted"])

      assert {:error, %Error{type: :report_failed, message: "Report request aborted"}} =
               Reports.await("req-1", config: config, interval: 1)
    end
  end

  describe "generate/2" do
    test "queues, waits and returns the outputs", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "POST", "/api/v1/reports", fn conn ->
        json(conn, 202, %{"requestId" => "req-1", "outputsUrl" => "https://tenant/x"})
      end)

      expect_status(bypass, "req-1", ["processing", "done"])

      Bypass.expect_once(bypass, "GET", "/api/v1/reports/req-1/outputs", fn conn ->
        json(conn, 200, %{"data" => [%{"outputId" => "cover", "location" => "https://tenant/y"}], "links" => %{}})
      end)

      assert {:ok, [%{"outputId" => "cover"}]} = Reports.generate(request(), config: config, interval: 1)
    end

    test "stops at the first failure", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "POST", "/api/v1/reports", fn conn ->
        json(conn, 202, %{"requestId" => "req-1"})
      end)

      expect_status(bypass, "req-1", ["failed"])

      assert {:error, %Error{type: :report_failed}} = Reports.generate(request(), config: config, interval: 1)
    end
  end

  describe "download_output/2" do
    test "downloads from an output map", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/temp-contents/abc123", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/pdf")
        |> Plug.Conn.resp(200, "%PDF-1.7 binary")
      end)

      output = %{"outputId" => "cover", "location" => "https://tenant:443/api/v1/temp-contents/abc123"}

      assert {:ok, "%PDF-1.7 binary"} = Reports.download_output(output, config: config)
    end

    test "keeps the query string of the location", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/temp-contents/abc123", fn conn ->
        assert conn.query_string == "inline=1"
        Plug.Conn.resp(conn, 200, "bytes")
      end)

      assert {:ok, "bytes"} =
               Reports.download_output("https://tenant:443/api/v1/temp-contents/abc123?inline=1", config: config)
    end

    test "rejects an output that has no location yet", %{config: config} do
      assert {:error, %Error{type: :validation_error}} =
               Reports.download_output(%{"outputId" => "cover", "status" => "processing"}, config: config)
    end

    test "returns not_found once the temporary content has expired", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/temp-contents/gone", fn conn ->
        json(conn, 404, %{"error" => "Not found"})
      end)

      assert {:error, %Error{type: :not_found}} =
               Reports.download_output("https://tenant/api/v1/temp-contents/gone", config: config)
    end
  end
end
