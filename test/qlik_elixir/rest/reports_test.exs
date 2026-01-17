defmodule QlikElixir.REST.ReportsTest do
  use ExUnit.Case, async: true

  alias QlikElixir.REST.Reports
  alias QlikElixir.{Config, Error}

  setup do
    bypass = Bypass.open()
    config = Config.new(api_key: "test-key", tenant_url: "http://localhost:#{bypass.port}")
    {:ok, bypass: bypass, config: config}
  end

  describe "list/1" do
    test "returns paginated reports", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/reports", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "data" => [
              %{"id" => "report-1", "name" => "Sales Report", "status" => "completed"},
              %{"id" => "report-2", "name" => "Q4 Summary", "status" => "processing"}
            ],
            "links" => %{}
          })
        )
      end)

      assert {:ok, %{"data" => reports}} = Reports.list(config: config)
      assert length(reports) == 2
    end

    test "supports pagination", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/reports", fn conn ->
        assert conn.query_string =~ "limit=10"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{"data" => [], "links" => %{}}))
      end)

      assert {:ok, _} = Reports.list(config: config, limit: 10)
    end

    test "supports appId filter", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/reports", fn conn ->
        assert conn.query_string =~ "appId=app-123"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{"data" => [], "links" => %{}}))
      end)

      assert {:ok, _} = Reports.list(config: config, app_id: "app-123")
    end

    test "supports status filter", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/reports", fn conn ->
        assert conn.query_string =~ "status=completed"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{"data" => [], "links" => %{}}))
      end)

      assert {:ok, _} = Reports.list(config: config, status: "completed")
    end
  end

  describe "get/2" do
    test "returns report by ID", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/reports/report-123", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "id" => "report-123",
            "name" => "Sales Report",
            "status" => "completed",
            "appId" => "app-456",
            "type" => "sense-excel-template",
            "createdAt" => "2024-01-15T10:00:00Z",
            "completedAt" => "2024-01-15T10:05:00Z"
          })
        )
      end)

      assert {:ok, report} = Reports.get("report-123", config: config)
      assert report["id"] == "report-123"
      assert report["status"] == "completed"
    end

    test "returns not_found for non-existent report", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/reports/not-found", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(404, Jason.encode!(%{"error" => "Not found"}))
      end)

      assert {:error, %Error{type: :not_found}} = Reports.get("not-found", config: config)
    end
  end

  describe "create/2" do
    test "creates a new report", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "POST", "/api/v1/reports", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)
        assert params["appId"] == "app-123"
        assert params["type"] == "sense-excel-template"
        assert params["output"]["outputId"] == "template-456"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          201,
          Jason.encode!(%{
            "id" => "report-new",
            "appId" => "app-123",
            "status" => "queued"
          })
        )
      end)

      params = %{
        appId: "app-123",
        type: "sense-excel-template",
        output: %{outputId: "template-456"}
      }

      assert {:ok, report} = Reports.create(params, config: config)
      assert report["id"] == "report-new"
      assert report["status"] == "queued"
    end
  end

  describe "delete/2" do
    test "deletes a report", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "DELETE", "/api/v1/reports/report-123", fn conn ->
        conn |> Plug.Conn.resp(204, "")
      end)

      assert :ok = Reports.delete("report-123", config: config)
    end

    test "returns not_found for non-existent report", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "DELETE", "/api/v1/reports/not-found", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(404, Jason.encode!(%{"error" => "Not found"}))
      end)

      assert {:error, %Error{type: :not_found}} = Reports.delete("not-found", config: config)
    end
  end

  describe "download/2" do
    test "returns download URL for report", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/reports/report-123/download", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "url" => "https://download.qlik.com/reports/report-123.xlsx",
            "expiresAt" => "2024-01-15T12:00:00Z"
          })
        )
      end)

      assert {:ok, download} = Reports.download("report-123", config: config)
      assert download["url"] =~ "report-123.xlsx"
    end

    test "returns not_found for non-existent report", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/reports/not-found/download", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(404, Jason.encode!(%{"error" => "Not found"}))
      end)

      assert {:error, %Error{type: :not_found}} = Reports.download("not-found", config: config)
    end
  end

  describe "get_status/2" do
    test "returns report status", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/reports/report-123/status", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "status" => "processing",
            "progress" => 75,
            "message" => "Generating charts..."
          })
        )
      end)

      assert {:ok, status} = Reports.get_status("report-123", config: config)
      assert status["status"] == "processing"
      assert status["progress"] == 75
    end
  end
end
