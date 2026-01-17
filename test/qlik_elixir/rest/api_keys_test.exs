defmodule QlikElixir.REST.APIKeysTest do
  use ExUnit.Case

  alias QlikElixir.{Config, Error}
  alias QlikElixir.REST.APIKeys

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
    test "returns list of API keys", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/api-keys", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            data: [
              %{id: "key-1", description: "Production key", status: "active"},
              %{id: "key-2", description: "Test key", status: "active"}
            ]
          })
        )
      end)

      assert {:ok, %{"data" => keys}} = APIKeys.list(config: config)
      assert length(keys) == 2
    end

    test "supports pagination", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/api-keys", fn conn ->
        assert conn.query_string =~ "limit=25"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{data: []}))
      end)

      assert {:ok, _} = APIKeys.list(config: config, limit: 25)
    end

    test "supports owner_id filter", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/api-keys", fn conn ->
        assert conn.query_string =~ "ownerId=user-123"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{data: []}))
      end)

      assert {:ok, _} = APIKeys.list(config: config, owner_id: "user-123")
    end

    test "supports status filter", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/api-keys", fn conn ->
        assert conn.query_string =~ "status=active"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{data: []}))
      end)

      assert {:ok, _} = APIKeys.list(config: config, status: "active")
    end

    test "supports sort parameter", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/api-keys", fn conn ->
        assert conn.query_string =~ "sort=-createdAt"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{data: []}))
      end)

      assert {:ok, _} = APIKeys.list(config: config, sort: "-createdAt")
    end
  end

  describe "get/2" do
    test "returns API key details", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/api-keys/key-123", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            id: "key-123",
            description: "Production key",
            status: "active",
            createdAt: "2024-01-01T00:00:00Z",
            lastUsed: "2024-01-15T12:00:00Z"
          })
        )
      end)

      assert {:ok, key} = APIKeys.get("key-123", config: config)
      assert key["id"] == "key-123"
      assert key["status"] == "active"
    end

    test "returns error for missing key", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/api-keys/missing", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(404, Jason.encode!(%{message: "Not found"}))
      end)

      assert {:error, %Error{type: :not_found}} = APIKeys.get("missing", config: config)
    end
  end

  describe "create/2" do
    test "creates a new API key", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "POST", "/api/v1/api-keys", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)
        assert params["description"] == "New API key"
        assert params["expiry"] == "2025-12-31T23:59:59Z"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          201,
          Jason.encode!(%{
            id: "new-key",
            description: "New API key",
            token: "eyJhbGciOiJFUzM4NCIsInR5cCI6IkpXVCJ9...",
            status: "active"
          })
        )
      end)

      params = %{description: "New API key", expiry: "2025-12-31T23:59:59Z"}
      assert {:ok, key} = APIKeys.create(params, config: config)
      assert key["id"] == "new-key"
      assert key["token"] != nil
    end
  end

  describe "update/3" do
    test "updates API key details", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "PATCH", "/api/v1/api-keys/key-123", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)
        assert params["description"] == "Updated description"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            id: "key-123",
            description: "Updated description",
            status: "active"
          })
        )
      end)

      assert {:ok, key} = APIKeys.update("key-123", %{description: "Updated description"}, config: config)
      assert key["description"] == "Updated description"
    end
  end

  describe "delete/2" do
    test "deletes an API key", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "DELETE", "/api/v1/api-keys/key-123", fn conn ->
        Plug.Conn.resp(conn, 204, "")
      end)

      assert :ok = APIKeys.delete("key-123", config: config)
    end

    test "returns error for missing key", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "DELETE", "/api/v1/api-keys/missing", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(404, Jason.encode!(%{message: "Not found"}))
      end)

      assert {:error, %Error{type: :not_found}} = APIKeys.delete("missing", config: config)
    end
  end

  describe "get_config/1" do
    test "returns API keys configuration", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/api-keys/configs/default", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            api_keys_enabled: true,
            max_api_key_expiry: "P365D",
            max_keys_per_user: 5
          })
        )
      end)

      assert {:ok, cfg} = APIKeys.get_config(config: config)
      assert cfg["api_keys_enabled"] == true
    end

    test "supports tenant_id parameter", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/api-keys/configs/tenant-456", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{api_keys_enabled: true}))
      end)

      assert {:ok, _} = APIKeys.get_config(config: config, tenant_id: "tenant-456")
    end
  end

  describe "update_config/2" do
    test "updates API keys configuration", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "PATCH", "/api/v1/api-keys/configs/default", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)
        assert params["api_keys_enabled"] == false

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            api_keys_enabled: false,
            max_api_key_expiry: "P365D"
          })
        )
      end)

      assert {:ok, cfg} = APIKeys.update_config(%{api_keys_enabled: false}, config: config)
      assert cfg["api_keys_enabled"] == false
    end
  end
end
