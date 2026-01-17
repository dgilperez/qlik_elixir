defmodule QlikElixir.REST.AutomationsTest do
  use ExUnit.Case

  alias QlikElixir.{Config, Error}
  alias QlikElixir.REST.Automations

  setup do
    bypass = Bypass.open()

    config =
      Config.new(
        api_key: "test-key",
        tenant_url: "http://localhost:#{bypass.port}",
        http_options: [retry: false]
      )

    {:ok, bypass: bypass, config: config}
  end

  describe "list/1" do
    test "returns list of automations", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/automations", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            data: [
              %{id: "auto-1", name: "Daily Reload", state: "enabled"},
              %{id: "auto-2", name: "Weekly Report", state: "disabled"}
            ]
          })
        )
      end)

      assert {:ok, %{"data" => automations}} = Automations.list(config: config)
      assert length(automations) == 2
    end

    test "supports pagination", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/automations", fn conn ->
        assert conn.query_string =~ "limit=20"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{data: []}))
      end)

      assert {:ok, _} = Automations.list(config: config, limit: 20)
    end

    test "supports filter by name", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/automations", fn conn ->
        assert conn.query_string =~ "name=Daily"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{data: []}))
      end)

      assert {:ok, _} = Automations.list(config: config, name: "Daily")
    end

    test "supports filter by state", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/automations", fn conn ->
        assert conn.query_string =~ "state=enabled"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{data: []}))
      end)

      assert {:ok, _} = Automations.list(config: config, state: "enabled")
    end
  end

  describe "get/2" do
    test "returns automation details", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/automations/auto-123", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            id: "auto-123",
            name: "Daily Reload",
            state: "enabled",
            ownerId: "user-456",
            createdAt: "2024-01-01T00:00:00Z"
          })
        )
      end)

      assert {:ok, auto} = Automations.get("auto-123", config: config)
      assert auto["id"] == "auto-123"
      assert auto["state"] == "enabled"
    end

    test "returns error for missing automation", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/automations/missing", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(404, Jason.encode!(%{message: "Not found"}))
      end)

      assert {:error, %Error{type: :not_found}} = Automations.get("missing", config: config)
    end
  end

  describe "create/2" do
    test "creates a new automation", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "POST", "/api/v1/automations", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)
        assert params["name"] == "New Automation"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          201,
          Jason.encode!(%{
            id: "new-auto",
            name: "New Automation",
            state: "disabled"
          })
        )
      end)

      params = %{name: "New Automation", workspace: %{}}
      assert {:ok, auto} = Automations.create(params, config: config)
      assert auto["id"] == "new-auto"
    end
  end

  describe "update/3" do
    test "updates automation details", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "PUT", "/api/v1/automations/auto-123", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)
        assert params["name"] == "Updated Name"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            id: "auto-123",
            name: "Updated Name",
            state: "enabled"
          })
        )
      end)

      assert {:ok, auto} = Automations.update("auto-123", %{name: "Updated Name"}, config: config)
      assert auto["name"] == "Updated Name"
    end
  end

  describe "delete/2" do
    test "deletes an automation", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "DELETE", "/api/v1/automations/auto-123", fn conn ->
        Plug.Conn.resp(conn, 204, "")
      end)

      assert :ok = Automations.delete("auto-123", config: config)
    end
  end

  describe "enable/2" do
    test "enables an automation", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "POST", "/api/v1/automations/auto-123/actions/enable", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            id: "auto-123",
            state: "enabled"
          })
        )
      end)

      assert {:ok, auto} = Automations.enable("auto-123", config: config)
      assert auto["state"] == "enabled"
    end
  end

  describe "disable/2" do
    test "disables an automation", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "POST", "/api/v1/automations/auto-123/actions/disable", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            id: "auto-123",
            state: "disabled"
          })
        )
      end)

      assert {:ok, auto} = Automations.disable("auto-123", config: config)
      assert auto["state"] == "disabled"
    end
  end

  describe "copy/2" do
    test "copies an automation", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "POST", "/api/v1/automations/auto-123/actions/copy", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          201,
          Jason.encode!(%{
            id: "auto-copy",
            name: "Daily Reload (Copy)",
            state: "disabled"
          })
        )
      end)

      assert {:ok, auto} = Automations.copy("auto-123", config: config)
      assert auto["id"] == "auto-copy"
    end
  end

  describe "change_owner/3" do
    test "changes automation owner", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "POST", "/api/v1/automations/auto-123/actions/change-owner", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)
        assert params["ownerId"] == "user-789"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{id: "auto-123", ownerId: "user-789"}))
      end)

      assert {:ok, auto} = Automations.change_owner("auto-123", "user-789", config: config)
      assert auto["ownerId"] == "user-789"
    end
  end

  describe "change_space/3" do
    test "moves automation to another space", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "POST", "/api/v1/automations/auto-123/actions/change-space", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)
        assert params["spaceId"] == "space-456"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{id: "auto-123", spaceId: "space-456"}))
      end)

      assert {:ok, auto} = Automations.change_space("auto-123", "space-456", config: config)
      assert auto["spaceId"] == "space-456"
    end
  end

  # Runs

  describe "list_runs/2" do
    test "returns automation runs", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/automations/auto-123/runs", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            data: [
              %{id: "run-1", status: "finished", startTime: "2024-01-15T10:00:00Z"},
              %{id: "run-2", status: "running", startTime: "2024-01-15T11:00:00Z"}
            ]
          })
        )
      end)

      assert {:ok, %{"data" => runs}} = Automations.list_runs("auto-123", config: config)
      assert length(runs) == 2
    end

    test "supports pagination", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/automations/auto-123/runs", fn conn ->
        assert conn.query_string =~ "limit=10"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{data: []}))
      end)

      assert {:ok, _} = Automations.list_runs("auto-123", config: config, limit: 10)
    end
  end

  describe "run/2" do
    test "triggers an automation run", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "POST", "/api/v1/automations/auto-123/actions/run", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          202,
          Jason.encode!(%{
            id: "run-new",
            status: "queued",
            startTime: "2024-01-15T12:00:00Z"
          })
        )
      end)

      assert {:ok, run} = Automations.run("auto-123", config: config)
      assert run["id"] == "run-new"
      assert run["status"] == "queued"
    end

    test "supports input parameters", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "POST", "/api/v1/automations/auto-123/actions/run", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)
        assert params["inputs"] == %{"param1" => "value1"}

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(202, Jason.encode!(%{id: "run-new", status: "queued"}))
      end)

      assert {:ok, _} = Automations.run("auto-123", config: config, inputs: %{"param1" => "value1"})
    end
  end

  describe "get_run/3" do
    test "returns run details", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/automations/auto-123/runs/run-456", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            id: "run-456",
            status: "finished",
            startTime: "2024-01-15T10:00:00Z",
            stopTime: "2024-01-15T10:05:00Z"
          })
        )
      end)

      assert {:ok, run} = Automations.get_run("auto-123", "run-456", config: config)
      assert run["id"] == "run-456"
      assert run["status"] == "finished"
    end
  end

  describe "stop_run/3" do
    test "stops a running automation", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "POST", "/api/v1/automations/auto-123/runs/run-456/actions/stop", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{id: "run-456", status: "stopped"}))
      end)

      assert {:ok, run} = Automations.stop_run("auto-123", "run-456", config: config)
      assert run["status"] == "stopped"
    end
  end

  describe "retry_run/3" do
    test "retries a failed run", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "POST", "/api/v1/automations/auto-123/runs/run-456/actions/retry", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(202, Jason.encode!(%{id: "run-retry", status: "queued"}))
      end)

      assert {:ok, run} = Automations.retry_run("auto-123", "run-456", config: config)
      assert run["id"] == "run-retry"
    end
  end

  describe "get_usage/1" do
    test "returns automation usage", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/automations/usage", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            runCount: 150,
            errorCount: 5,
            executionTimeMs: 45_000
          })
        )
      end)

      assert {:ok, usage} = Automations.get_usage(config: config)
      assert usage["runCount"] == 150
    end
  end
end
