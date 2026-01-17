defmodule QlikElixir.REST.SpacesTest do
  use ExUnit.Case

  alias QlikElixir.{Config, Error}
  alias QlikElixir.REST.Spaces

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
    test "returns list of spaces", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/spaces", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            data: [
              %{id: "space-1", name: "Development", type: "shared"},
              %{id: "space-2", name: "Production", type: "managed"}
            ]
          })
        )
      end)

      assert {:ok, %{"data" => spaces}} = Spaces.list(config: config)
      assert length(spaces) == 2
    end

    test "supports type filter", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/spaces", fn conn ->
        assert conn.query_string =~ "type=shared"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{data: []}))
      end)

      assert {:ok, _} = Spaces.list(config: config, type: "shared")
    end

    test "supports pagination", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/spaces", fn conn ->
        assert conn.query_string =~ "limit=20"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{data: []}))
      end)

      assert {:ok, _} = Spaces.list(config: config, limit: 20)
    end
  end

  describe "get/2" do
    test "returns space details", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/spaces/space-123", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            id: "space-123",
            name: "Development",
            type: "shared",
            description: "Dev environment"
          })
        )
      end)

      assert {:ok, space} = Spaces.get("space-123", config: config)
      assert space["id"] == "space-123"
      assert space["type"] == "shared"
    end

    test "returns error for missing space", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/spaces/missing", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(404, Jason.encode!(%{message: "Not found"}))
      end)

      assert {:error, %Error{type: :not_found}} = Spaces.get("missing", config: config)
    end
  end

  describe "create/2" do
    test "creates a shared space", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "POST", "/api/v1/spaces", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)
        assert params["name"] == "New Space"
        assert params["type"] == "shared"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          201,
          Jason.encode!(%{
            id: "new-space-id",
            name: "New Space",
            type: "shared"
          })
        )
      end)

      assert {:ok, space} = Spaces.create(%{name: "New Space", type: "shared"}, config: config)
      assert space["id"] == "new-space-id"
    end
  end

  describe "update/3" do
    test "updates space via PATCH with JSON Patch format", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "PATCH", "/api/v1/spaces/space-123", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        patches = Jason.decode!(body)
        # Verify JSON Patch format
        assert is_list(patches)
        patch = Enum.find(patches, &(&1["path"] == "/description"))
        assert patch["op"] == "replace"
        assert patch["value"] == "Updated description"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            id: "space-123",
            description: "Updated description"
          })
        )
      end)

      assert {:ok, space} = Spaces.update("space-123", %{description: "Updated description"}, config: config)
      assert space["description"] == "Updated description"
    end
  end

  describe "delete/2" do
    test "deletes a space", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "DELETE", "/api/v1/spaces/space-123", fn conn ->
        Plug.Conn.resp(conn, 204, "")
      end)

      assert :ok = Spaces.delete("space-123", config: config)
    end
  end

  describe "list_assignments/2" do
    test "lists space assignments", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/spaces/space-123/assignments", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            data: [
              %{id: "assign-1", type: "user", assigneeId: "user-1", roles: ["consumer"]},
              %{id: "assign-2", type: "user", assigneeId: "user-2", roles: ["producer"]}
            ]
          })
        )
      end)

      assert {:ok, %{"data" => assignments}} = Spaces.list_assignments("space-123", config: config)
      assert length(assignments) == 2
    end
  end

  describe "create_assignment/3" do
    test "creates an assignment", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "POST", "/api/v1/spaces/space-123/assignments", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)
        assert params["type"] == "user"
        assert params["assigneeId"] == "user-456"
        assert params["roles"] == ["consumer"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          201,
          Jason.encode!(%{
            id: "new-assign",
            type: "user",
            assigneeId: "user-456"
          })
        )
      end)

      params = %{type: "user", assignee_id: "user-456", roles: ["consumer"]}
      assert {:ok, assignment} = Spaces.create_assignment("space-123", params, config: config)
      assert assignment["id"] == "new-assign"
    end
  end

  describe "delete_assignment/3" do
    test "deletes an assignment", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "DELETE", "/api/v1/spaces/space-123/assignments/assign-456", fn conn ->
        Plug.Conn.resp(conn, 204, "")
      end)

      assert :ok = Spaces.delete_assignment("space-123", "assign-456", config: config)
    end
  end

  describe "list_types/1" do
    test "lists available space types", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/spaces/types", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            data: [
              %{name: "shared", actions: ["create", "read"]},
              %{name: "managed", actions: ["read"]}
            ]
          })
        )
      end)

      assert {:ok, %{"data" => types}} = Spaces.list_types(config: config)
      assert length(types) == 2
    end
  end
end
