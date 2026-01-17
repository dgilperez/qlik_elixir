defmodule QlikElixir.REST.TenantsTest do
  use ExUnit.Case, async: true

  alias QlikElixir.REST.Tenants
  alias QlikElixir.{Config, Error}

  setup do
    bypass = Bypass.open()
    config = Config.new(api_key: "test-key", tenant_url: "http://localhost:#{bypass.port}")
    {:ok, bypass: bypass, config: config}
  end

  describe "me/1" do
    test "returns current tenant", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/tenants/me", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "id" => "tenant-123",
            "name" => "My Tenant",
            "hostnames" => ["mytenant.qlikcloud.com"],
            "createdByUser" => "user-abc",
            "created" => "2024-01-01T00:00:00Z"
          })
        )
      end)

      assert {:ok, tenant} = Tenants.me(config: config)
      assert tenant["id"] == "tenant-123"
      assert tenant["name"] == "My Tenant"
    end
  end

  describe "get/2" do
    test "returns tenant by ID", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/tenants/tenant-123", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "id" => "tenant-123",
            "name" => "Test Tenant",
            "hostnames" => ["test.qlikcloud.com"],
            "status" => "active"
          })
        )
      end)

      assert {:ok, tenant} = Tenants.get("tenant-123", config: config)
      assert tenant["id"] == "tenant-123"
      assert tenant["status"] == "active"
    end

    test "returns not_found for non-existent tenant", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/tenants/not-found", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(404, Jason.encode!(%{"error" => "Not found"}))
      end)

      assert {:error, %Error{type: :not_found}} = Tenants.get("not-found", config: config)
    end
  end

  describe "create/2" do
    test "creates a new tenant", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "POST", "/api/v1/tenants", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)
        assert params["name"] == "New Tenant"
        assert params["licenseKey"] == "license-key-123"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          201,
          Jason.encode!(%{
            "id" => "tenant-new",
            "name" => "New Tenant",
            "status" => "active"
          })
        )
      end)

      params = %{name: "New Tenant", licenseKey: "license-key-123"}
      assert {:ok, tenant} = Tenants.create(params, config: config)
      assert tenant["id"] == "tenant-new"
    end
  end

  describe "update/3" do
    test "updates tenant settings", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "PATCH", "/api/v1/tenants/tenant-123", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)
        assert params["name"] == "Updated Tenant"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "id" => "tenant-123",
            "name" => "Updated Tenant"
          })
        )
      end)

      assert {:ok, tenant} = Tenants.update("tenant-123", %{name: "Updated Tenant"}, config: config)
      assert tenant["name"] == "Updated Tenant"
    end
  end

  describe "deactivate/2" do
    test "deactivates a tenant", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "POST", "/api/v1/tenants/tenant-123/actions/deactivate", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "id" => "tenant-123",
            "status" => "disabled"
          })
        )
      end)

      assert {:ok, tenant} = Tenants.deactivate("tenant-123", config: config)
      assert tenant["status"] == "disabled"
    end
  end

  describe "reactivate/2" do
    test "reactivates a tenant", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "POST", "/api/v1/tenants/tenant-123/actions/reactivate", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "id" => "tenant-123",
            "status" => "active"
          })
        )
      end)

      assert {:ok, tenant} = Tenants.reactivate("tenant-123", config: config)
      assert tenant["status"] == "active"
    end
  end
end
