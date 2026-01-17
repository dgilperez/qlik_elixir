defmodule QlikElixir.REST.AppsTest do
  use ExUnit.Case

  alias QlikElixir.{Config, Error}
  alias QlikElixir.REST.Apps

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
    test "returns list of apps", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/apps", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            data: [
              %{id: "app-1", name: "Sales Dashboard"},
              %{id: "app-2", name: "HR Analytics"}
            ]
          })
        )
      end)

      assert {:ok, %{"data" => apps}} = Apps.list(config: config)
      assert length(apps) == 2
    end

    test "supports pagination options", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/apps", fn conn ->
        assert conn.query_string =~ "limit=10"
        assert conn.query_string =~ "next=cursor123"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{data: []}))
      end)

      assert {:ok, _} = Apps.list(config: config, limit: 10, next: "cursor123")
    end

    test "supports space filter", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/apps", fn conn ->
        assert conn.query_string =~ "spaceId=space-123"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{data: []}))
      end)

      assert {:ok, _} = Apps.list(config: config, space_id: "space-123")
    end
  end

  describe "get/2" do
    test "returns app details", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/apps/app-123", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            id: "app-123",
            name: "Sales Dashboard",
            description: "Q4 Sales Analysis"
          })
        )
      end)

      assert {:ok, app} = Apps.get("app-123", config: config)
      assert app["id"] == "app-123"
      assert app["name"] == "Sales Dashboard"
    end

    test "returns error when app not found", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/apps/missing", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(404, Jason.encode!(%{message: "App not found"}))
      end)

      assert {:error, %Error{type: :not_found}} = Apps.get("missing", config: config)
    end
  end

  describe "create/2" do
    test "creates a new app", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "POST", "/api/v1/apps", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)
        assert params["attributes"]["name"] == "New App"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          201,
          Jason.encode!(%{
            id: "new-app-id",
            name: "New App"
          })
        )
      end)

      assert {:ok, app} = Apps.create(%{name: "New App"}, config: config)
      assert app["id"] == "new-app-id"
    end

    test "creates app in specific space", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "POST", "/api/v1/apps", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)
        assert params["attributes"]["spaceId"] == "space-456"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(201, Jason.encode!(%{id: "new-app"}))
      end)

      assert {:ok, _} = Apps.create(%{name: "App", space_id: "space-456"}, config: config)
    end
  end

  describe "delete/2" do
    test "deletes an app", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "DELETE", "/api/v1/apps/app-123", fn conn ->
        Plug.Conn.resp(conn, 204, "")
      end)

      assert :ok = Apps.delete("app-123", config: config)
    end

    test "returns error when app not found", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "DELETE", "/api/v1/apps/missing", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(404, Jason.encode!(%{message: "Not found"}))
      end)

      assert {:error, %Error{type: :not_found, message: "App not found"}} = Apps.delete("missing", config: config)
    end
  end

  describe "copy/2" do
    test "copies an app", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "POST", "/api/v1/apps/app-123/copy", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)
        assert params["attributes"]["name"] == "Copy of App"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          201,
          Jason.encode!(%{
            id: "copied-app-id",
            name: "Copy of App"
          })
        )
      end)

      assert {:ok, app} = Apps.copy("app-123", name: "Copy of App", config: config)
      assert app["id"] == "copied-app-id"
    end
  end

  describe "update/3" do
    test "updates app properties", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "PUT", "/api/v1/apps/app-123", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)
        assert params["attributes"]["name"] == "Renamed App"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            id: "app-123",
            name: "Renamed App"
          })
        )
      end)

      assert {:ok, app} = Apps.update("app-123", %{name: "Renamed App"}, config: config)
      assert app["name"] == "Renamed App"
    end
  end

  describe "get_metadata/2" do
    test "returns app metadata", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/apps/app-123/data/metadata", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            reload_time: "2026-01-15T10:00:00Z",
            static_byte_size: 1_024_000
          })
        )
      end)

      assert {:ok, metadata} = Apps.get_metadata("app-123", config: config)
      assert metadata["reload_time"]
    end
  end

  describe "get_lineage/2" do
    test "returns data lineage", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/apps/app-123/data/lineage", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            data: [%{discriminator: "table", statement: "SELECT *"}]
          })
        )
      end)

      assert {:ok, lineage} = Apps.get_lineage("app-123", config: config)
      assert lineage["data"]
    end
  end
end
