defmodule QlikElixir.REST.RolesTest do
  use ExUnit.Case, async: true

  alias QlikElixir.REST.Roles
  alias QlikElixir.{Config, Error}

  setup do
    bypass = Bypass.open()
    config = Config.new(api_key: "test-key", tenant_url: "http://localhost:#{bypass.port}")
    {:ok, bypass: bypass, config: config}
  end

  describe "list/1" do
    test "returns paginated roles", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/roles", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "data" => [
              %{"id" => "role-1", "name" => "TenantAdmin", "type" => "default"},
              %{"id" => "role-2", "name" => "Developer", "type" => "default"},
              %{"id" => "role-3", "name" => "Analyzer", "type" => "default"}
            ],
            "links" => %{}
          })
        )
      end)

      assert {:ok, %{"data" => roles}} = Roles.list(config: config)
      assert length(roles) == 3
    end

    test "supports pagination", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/roles", fn conn ->
        assert conn.query_string =~ "limit=5"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{"data" => [], "links" => %{}}))
      end)

      assert {:ok, _} = Roles.list(config: config, limit: 5)
    end

    test "supports name filter", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/roles", fn conn ->
        assert conn.query_string =~ "name=Admin"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{"data" => [], "links" => %{}}))
      end)

      assert {:ok, _} = Roles.list(config: config, name: "Admin")
    end

    test "supports type filter", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/roles", fn conn ->
        assert conn.query_string =~ "type=default"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{"data" => [], "links" => %{}}))
      end)

      assert {:ok, _} = Roles.list(config: config, type: "default")
    end
  end

  describe "get/2" do
    test "returns role by ID", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/roles/role-123", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "id" => "role-123",
            "name" => "TenantAdmin",
            "type" => "default",
            "description" => "Full tenant administration",
            "permissions" => ["admin:*", "apps:*"]
          })
        )
      end)

      assert {:ok, role} = Roles.get("role-123", config: config)
      assert role["id"] == "role-123"
      assert role["name"] == "TenantAdmin"
      assert "admin:*" in role["permissions"]
    end

    test "returns not_found for non-existent role", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/roles/not-found", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(404, Jason.encode!(%{"error" => "Not found"}))
      end)

      assert {:error, %Error{type: :not_found}} = Roles.get("not-found", config: config)
    end
  end
end
