defmodule QlikElixir.REST.GroupsTest do
  use ExUnit.Case, async: true

  alias QlikElixir.REST.Groups
  alias QlikElixir.{Config, Error}

  setup do
    bypass = Bypass.open()
    config = Config.new(api_key: "test-key", tenant_url: "http://localhost:#{bypass.port}")
    {:ok, bypass: bypass, config: config}
  end

  describe "list/1" do
    test "returns paginated groups", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/groups", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "data" => [
              %{"id" => "group-1", "name" => "Developers"},
              %{"id" => "group-2", "name" => "Analysts"}
            ],
            "links" => %{}
          })
        )
      end)

      assert {:ok, %{"data" => groups}} = Groups.list(config: config)
      assert length(groups) == 2
    end

    test "supports pagination", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/groups", fn conn ->
        assert conn.query_string =~ "limit=10"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{"data" => [], "links" => %{}}))
      end)

      assert {:ok, _} = Groups.list(config: config, limit: 10)
    end

    test "supports name filter", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/groups", fn conn ->
        assert conn.query_string =~ "name=Dev"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{"data" => [], "links" => %{}}))
      end)

      assert {:ok, _} = Groups.list(config: config, name: "Dev")
    end
  end

  describe "get/2" do
    test "returns group by ID", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/groups/group-123", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "id" => "group-123",
            "name" => "Developers",
            "tenantId" => "tenant-abc",
            "createdAt" => "2024-01-01T00:00:00Z"
          })
        )
      end)

      assert {:ok, group} = Groups.get("group-123", config: config)
      assert group["id"] == "group-123"
      assert group["name"] == "Developers"
    end

    test "returns not_found for non-existent group", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/groups/not-found", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(404, Jason.encode!(%{"error" => "Not found"}))
      end)

      assert {:error, %Error{type: :not_found}} = Groups.get("not-found", config: config)
    end
  end

  describe "create/2" do
    test "creates a new group", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "POST", "/api/v1/groups", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)
        assert params["name"] == "New Group"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          201,
          Jason.encode!(%{
            "id" => "group-new",
            "name" => "New Group"
          })
        )
      end)

      params = %{name: "New Group"}
      assert {:ok, group} = Groups.create(params, config: config)
      assert group["id"] == "group-new"
    end
  end

  describe "update/3" do
    test "updates a group", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "PATCH", "/api/v1/groups/group-123", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)
        assert params["name"] == "Updated Group"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "id" => "group-123",
            "name" => "Updated Group"
          })
        )
      end)

      assert {:ok, group} = Groups.update("group-123", %{name: "Updated Group"}, config: config)
      assert group["name"] == "Updated Group"
    end
  end

  describe "delete/2" do
    test "deletes a group", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "DELETE", "/api/v1/groups/group-123", fn conn ->
        conn
        |> Plug.Conn.resp(204, "")
      end)

      assert :ok = Groups.delete("group-123", config: config)
    end

    test "returns not_found for non-existent group", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "DELETE", "/api/v1/groups/not-found", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(404, Jason.encode!(%{"error" => "Not found"}))
      end)

      assert {:error, %Error{type: :not_found}} = Groups.delete("not-found", config: config)
    end
  end

  describe "list_settings/1" do
    test "returns group settings", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/groups/settings", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "autoCreateGroups" => true,
            "syncIdpGroups" => false
          })
        )
      end)

      assert {:ok, settings} = Groups.list_settings(config: config)
      assert settings["autoCreateGroups"] == true
    end
  end

  describe "update_settings/2" do
    test "updates group settings", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "PATCH", "/api/v1/groups/settings", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)
        assert params["autoCreateGroups"] == false

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "autoCreateGroups" => false
          })
        )
      end)

      assert {:ok, settings} = Groups.update_settings(%{autoCreateGroups: false}, config: config)
      assert settings["autoCreateGroups"] == false
    end
  end
end
