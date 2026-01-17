defmodule QlikElixir.REST.ReloadsTest do
  use ExUnit.Case

  alias QlikElixir.{Config, Error}
  alias QlikElixir.REST.Reloads

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
    test "returns list of reloads", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/reloads", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            data: [
              %{id: "reload-1", appId: "app-1", status: "SUCCEEDED"},
              %{id: "reload-2", appId: "app-2", status: "QUEUED"}
            ]
          })
        )
      end)

      assert {:ok, %{"data" => reloads}} = Reloads.list(config: config)
      assert length(reloads) == 2
    end

    test "supports app_id filter", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/reloads", fn conn ->
        assert conn.query_string =~ "appId=app-123"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{data: []}))
      end)

      assert {:ok, _} = Reloads.list(config: config, app_id: "app-123")
    end

    test "supports status filter", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/reloads", fn conn ->
        assert conn.query_string =~ "status=SUCCEEDED"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{data: []}))
      end)

      assert {:ok, _} = Reloads.list(config: config, status: "SUCCEEDED")
    end

    test "supports pagination", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/reloads", fn conn ->
        assert conn.query_string =~ "limit=10"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{data: []}))
      end)

      assert {:ok, _} = Reloads.list(config: config, limit: 10)
    end
  end

  describe "get/2" do
    test "returns reload details", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/reloads/reload-123", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            id: "reload-123",
            appId: "app-456",
            status: "SUCCEEDED",
            duration: "PT5M30S"
          })
        )
      end)

      assert {:ok, reload} = Reloads.get("reload-123", config: config)
      assert reload["id"] == "reload-123"
      assert reload["status"] == "SUCCEEDED"
    end

    test "returns error for missing reload", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/reloads/missing", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(404, Jason.encode!(%{message: "Not found"}))
      end)

      assert {:error, %Error{type: :not_found}} = Reloads.get("missing", config: config)
    end
  end

  describe "create/2" do
    test "triggers a reload for an app", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "POST", "/api/v1/reloads", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)
        assert params["appId"] == "app-123"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          201,
          Jason.encode!(%{
            id: "reload-new",
            appId: "app-123",
            status: "QUEUED"
          })
        )
      end)

      assert {:ok, reload} = Reloads.create("app-123", config: config)
      assert reload["id"] == "reload-new"
      assert reload["status"] == "QUEUED"
    end

    test "supports partial reload option", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "POST", "/api/v1/reloads", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)
        assert params["partial"] == true

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(201, Jason.encode!(%{id: "reload-partial", status: "QUEUED"}))
      end)

      assert {:ok, _} = Reloads.create("app-123", config: config, partial: true)
    end
  end

  describe "cancel/2" do
    test "cancels a queued reload", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "POST", "/api/v1/reloads/reload-123/actions/cancel", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            id: "reload-123",
            status: "CANCELING"
          })
        )
      end)

      assert {:ok, reload} = Reloads.cancel("reload-123", config: config)
      assert reload["status"] == "CANCELING"
    end

    test "returns error when cancel fails", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "POST", "/api/v1/reloads/completed/actions/cancel", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(400, Jason.encode!(%{message: "Cannot cancel completed reload"}))
      end)

      assert {:error, %Error{}} = Reloads.cancel("completed", config: config)
    end
  end
end
