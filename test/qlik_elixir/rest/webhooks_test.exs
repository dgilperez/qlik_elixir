defmodule QlikElixir.REST.WebhooksTest do
  use ExUnit.Case

  alias QlikElixir.{Config, Error}
  alias QlikElixir.REST.Webhooks

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
    test "returns list of webhooks", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/webhooks", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            data: [
              %{id: "hook-1", name: "Reload Complete", url: "https://example.com/hook1"},
              %{id: "hook-2", name: "App Created", url: "https://example.com/hook2"}
            ]
          })
        )
      end)

      assert {:ok, %{"data" => webhooks}} = Webhooks.list(config: config)
      assert length(webhooks) == 2
    end

    test "supports pagination", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/webhooks", fn conn ->
        assert conn.query_string =~ "limit=25"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{data: []}))
      end)

      assert {:ok, _} = Webhooks.list(config: config, limit: 25)
    end

    test "supports filter by name", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/webhooks", fn conn ->
        assert conn.query_string =~ "name=Reload"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{data: []}))
      end)

      assert {:ok, _} = Webhooks.list(config: config, name: "Reload")
    end

    test "supports filter by enabled status", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/webhooks", fn conn ->
        assert conn.query_string =~ "enabled=true"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{data: []}))
      end)

      assert {:ok, _} = Webhooks.list(config: config, enabled: true)
    end
  end

  describe "get/2" do
    test "returns webhook details", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/webhooks/hook-123", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            id: "hook-123",
            name: "Reload Complete",
            url: "https://example.com/webhook",
            enabled: true,
            eventTypes: ["com.qlik.v1.reload.finished"]
          })
        )
      end)

      assert {:ok, webhook} = Webhooks.get("hook-123", config: config)
      assert webhook["id"] == "hook-123"
      assert webhook["enabled"] == true
    end

    test "returns error for missing webhook", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/webhooks/missing", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(404, Jason.encode!(%{message: "Not found"}))
      end)

      assert {:error, %Error{type: :not_found}} = Webhooks.get("missing", config: config)
    end
  end

  describe "create/2" do
    test "creates a new webhook", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "POST", "/api/v1/webhooks", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)
        assert params["name"] == "New Webhook"
        assert params["url"] == "https://example.com/new"
        assert params["eventTypes"] == ["com.qlik.v1.app.created"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          201,
          Jason.encode!(%{
            id: "new-hook",
            name: "New Webhook",
            url: "https://example.com/new",
            enabled: true
          })
        )
      end)

      params = %{
        name: "New Webhook",
        url: "https://example.com/new",
        eventTypes: ["com.qlik.v1.app.created"]
      }

      assert {:ok, webhook} = Webhooks.create(params, config: config)
      assert webhook["id"] == "new-hook"
    end
  end

  describe "update/3" do
    test "updates webhook details", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "PATCH", "/api/v1/webhooks/hook-123", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)
        assert params["name"] == "Updated Name"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            id: "hook-123",
            name: "Updated Name",
            enabled: true
          })
        )
      end)

      assert {:ok, webhook} = Webhooks.update("hook-123", %{name: "Updated Name"}, config: config)
      assert webhook["name"] == "Updated Name"
    end
  end

  describe "delete/2" do
    test "deletes a webhook", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "DELETE", "/api/v1/webhooks/hook-123", fn conn ->
        Plug.Conn.resp(conn, 204, "")
      end)

      assert :ok = Webhooks.delete("hook-123", config: config)
    end

    test "returns error for missing webhook", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "DELETE", "/api/v1/webhooks/missing", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(404, Jason.encode!(%{message: "Not found"}))
      end)

      assert {:error, %Error{type: :not_found}} = Webhooks.delete("missing", config: config)
    end
  end

  describe "list_event_types/1" do
    test "returns available event types", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/webhooks/event-types", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            data: [
              %{name: "com.qlik.v1.app.created", description: "App created"},
              %{name: "com.qlik.v1.app.deleted", description: "App deleted"},
              %{name: "com.qlik.v1.reload.finished", description: "Reload finished"}
            ]
          })
        )
      end)

      assert {:ok, %{"data" => types}} = Webhooks.list_event_types(config: config)
      assert length(types) == 3
    end
  end

  # Deliveries

  describe "list_deliveries/2" do
    test "returns webhook deliveries", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/webhooks/hook-123/deliveries", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            data: [
              %{id: "del-1", status: "success", triggeredAt: "2024-01-15T10:00:00Z"},
              %{id: "del-2", status: "failed", triggeredAt: "2024-01-15T11:00:00Z"}
            ]
          })
        )
      end)

      assert {:ok, %{"data" => deliveries}} = Webhooks.list_deliveries("hook-123", config: config)
      assert length(deliveries) == 2
    end

    test "supports pagination", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/webhooks/hook-123/deliveries", fn conn ->
        assert conn.query_string =~ "limit=10"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{data: []}))
      end)

      assert {:ok, _} = Webhooks.list_deliveries("hook-123", config: config, limit: 10)
    end

    test "supports status filter", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/webhooks/hook-123/deliveries", fn conn ->
        assert conn.query_string =~ "status=failed"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{data: []}))
      end)

      assert {:ok, _} = Webhooks.list_deliveries("hook-123", config: config, status: "failed")
    end
  end

  describe "get_delivery/3" do
    test "returns delivery details", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/webhooks/hook-123/deliveries/del-456", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            id: "del-456",
            status: "success",
            triggeredAt: "2024-01-15T10:00:00Z",
            request: %{headers: %{}, body: "{}"},
            response: %{statusCode: 200, body: "OK"}
          })
        )
      end)

      assert {:ok, delivery} = Webhooks.get_delivery("hook-123", "del-456", config: config)
      assert delivery["id"] == "del-456"
      assert delivery["status"] == "success"
    end
  end

  describe "resend_delivery/3" do
    test "resends a failed delivery", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "POST", "/api/v1/webhooks/hook-123/deliveries/del-456/actions/resend", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          202,
          Jason.encode!(%{
            id: "del-resend",
            status: "pending",
            triggeredAt: "2024-01-15T12:00:00Z"
          })
        )
      end)

      assert {:ok, delivery} = Webhooks.resend_delivery("hook-123", "del-456", config: config)
      assert delivery["id"] == "del-resend"
      assert delivery["status"] == "pending"
    end
  end
end
