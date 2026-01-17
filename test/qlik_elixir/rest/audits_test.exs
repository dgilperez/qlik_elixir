defmodule QlikElixir.REST.AuditsTest do
  use ExUnit.Case, async: true

  alias QlikElixir.REST.Audits
  alias QlikElixir.{Config, Error}

  setup do
    bypass = Bypass.open()
    config = Config.new(api_key: "test-key", tenant_url: "http://localhost:#{bypass.port}")
    {:ok, bypass: bypass, config: config}
  end

  describe "list/1" do
    test "returns paginated audit events", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/audits", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{
          "data" => [
            %{
              "id" => "audit-1",
              "eventType" => "com.qlik.v1.app.created",
              "eventTime" => "2024-01-15T10:00:00Z",
              "userId" => "user-abc"
            },
            %{
              "id" => "audit-2",
              "eventType" => "com.qlik.v1.app.opened",
              "eventTime" => "2024-01-15T11:00:00Z",
              "userId" => "user-def"
            }
          ],
          "links" => %{}
        }))
      end)

      assert {:ok, %{"data" => events}} = Audits.list(config: config)
      assert length(events) == 2
    end

    test "supports pagination", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/audits", fn conn ->
        assert conn.query_string =~ "limit=20"
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{"data" => [], "links" => %{}}))
      end)

      assert {:ok, _} = Audits.list(config: config, limit: 20)
    end

    test "supports eventType filter", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/audits", fn conn ->
        assert conn.query_string =~ "eventType=com.qlik.v1.app.created"
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{"data" => [], "links" => %{}}))
      end)

      assert {:ok, _} = Audits.list(config: config, event_type: "com.qlik.v1.app.created")
    end

    test "supports userId filter", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/audits", fn conn ->
        assert conn.query_string =~ "userId=user-123"
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{"data" => [], "links" => %{}}))
      end)

      assert {:ok, _} = Audits.list(config: config, user_id: "user-123")
    end

    test "supports source filter", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/audits", fn conn ->
        assert conn.query_string =~ "source=com.qlik"
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{"data" => [], "links" => %{}}))
      end)

      assert {:ok, _} = Audits.list(config: config, source: "com.qlik")
    end
  end

  describe "get/2" do
    test "returns audit event by ID", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/audits/audit-123", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{
          "id" => "audit-123",
          "eventType" => "com.qlik.v1.app.created",
          "eventTime" => "2024-01-15T10:00:00Z",
          "userId" => "user-abc",
          "source" => "com.qlik/engine",
          "data" => %{
            "appId" => "app-123",
            "name" => "My App"
          }
        }))
      end)

      assert {:ok, event} = Audits.get("audit-123", config: config)
      assert event["id"] == "audit-123"
      assert event["eventType"] == "com.qlik.v1.app.created"
      assert event["data"]["appId"] == "app-123"
    end

    test "returns not_found for non-existent audit", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/audits/not-found", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(404, Jason.encode!(%{"error" => "Not found"}))
      end)

      assert {:error, %Error{type: :not_found}} = Audits.get("not-found", config: config)
    end
  end

  describe "list_sources/1" do
    test "returns available audit sources", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/audits/sources", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{
          "data" => [
            %{"id" => "com.qlik/engine", "name" => "Qlik Engine"},
            %{"id" => "com.qlik/hub", "name" => "Qlik Hub"}
          ]
        }))
      end)

      assert {:ok, %{"data" => sources}} = Audits.list_sources(config: config)
      assert length(sources) == 2
    end
  end

  describe "list_types/1" do
    test "returns available audit event types", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/audits/types", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{
          "data" => [
            %{"eventType" => "com.qlik.v1.app.created"},
            %{"eventType" => "com.qlik.v1.app.deleted"},
            %{"eventType" => "com.qlik.v1.user.login"}
          ]
        }))
      end)

      assert {:ok, %{"data" => types}} = Audits.list_types(config: config)
      assert length(types) == 3
    end
  end

  describe "get_settings/1" do
    test "returns audit settings", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/audits/settings", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{
          "eventTTL" => 90,
          "archiveEnabled" => true
        }))
      end)

      assert {:ok, settings} = Audits.get_settings(config: config)
      assert settings["eventTTL"] == 90
    end
  end
end
