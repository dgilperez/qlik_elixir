defmodule QlikElixir.REST.ItemsTest do
  use ExUnit.Case, async: true

  alias QlikElixir.REST.Items
  alias QlikElixir.{Config, Error}

  setup do
    bypass = Bypass.open()
    config = Config.new(api_key: "test-key", tenant_url: "http://localhost:#{bypass.port}")
    {:ok, bypass: bypass, config: config}
  end

  describe "list/1" do
    test "returns paginated items", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/items", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "data" => [
              %{"id" => "item-1", "name" => "App 1", "resourceType" => "app"},
              %{"id" => "item-2", "name" => "Space 1", "resourceType" => "space"}
            ],
            "links" => %{}
          })
        )
      end)

      assert {:ok, %{"data" => items}} = Items.list(config: config)
      assert length(items) == 2
    end

    test "supports pagination", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/items", fn conn ->
        assert conn.query_string =~ "limit=10"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{"data" => [], "links" => %{}}))
      end)

      assert {:ok, _} = Items.list(config: config, limit: 10)
    end

    test "supports resourceType filter", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/items", fn conn ->
        assert conn.query_string =~ "resourceType=app"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{"data" => [], "links" => %{}}))
      end)

      assert {:ok, _} = Items.list(config: config, resource_type: "app")
    end

    test "supports spaceId filter", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/items", fn conn ->
        assert conn.query_string =~ "spaceId=space-123"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{"data" => [], "links" => %{}}))
      end)

      assert {:ok, _} = Items.list(config: config, space_id: "space-123")
    end

    test "supports name filter", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/items", fn conn ->
        assert conn.query_string =~ "name=SalesApp"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{"data" => [], "links" => %{}}))
      end)

      assert {:ok, _} = Items.list(config: config, name: "SalesApp")
    end

    test "supports ownerId filter", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/items", fn conn ->
        assert conn.query_string =~ "ownerId=user-abc"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{"data" => [], "links" => %{}}))
      end)

      assert {:ok, _} = Items.list(config: config, owner_id: "user-abc")
    end

    test "supports shared filter", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/items", fn conn ->
        assert conn.query_string =~ "shared=true"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{"data" => [], "links" => %{}}))
      end)

      assert {:ok, _} = Items.list(config: config, shared: true)
    end

    test "supports sort parameter", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/items", fn conn ->
        assert conn.query_string =~ "sort=-updatedAt"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{"data" => [], "links" => %{}}))
      end)

      assert {:ok, _} = Items.list(config: config, sort: "-updatedAt")
    end
  end

  describe "get/2" do
    test "returns item by ID", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/items/item-123", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "id" => "item-123",
            "name" => "My App",
            "resourceType" => "app",
            "resourceId" => "app-456",
            "spaceId" => "space-789",
            "ownerId" => "user-abc",
            "createdAt" => "2024-01-01T00:00:00Z",
            "updatedAt" => "2024-01-15T00:00:00Z"
          })
        )
      end)

      assert {:ok, item} = Items.get("item-123", config: config)
      assert item["id"] == "item-123"
      assert item["resourceType"] == "app"
    end

    test "returns not_found for non-existent item", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/items/not-found", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(404, Jason.encode!(%{"error" => "Not found"}))
      end)

      assert {:error, %Error{type: :not_found}} = Items.get("not-found", config: config)
    end
  end

  describe "update/3" do
    test "updates an item", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "PUT", "/api/v1/items/item-123", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)
        assert params["name"] == "Updated Name"
        assert params["description"] == "New description"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "id" => "item-123",
            "name" => "Updated Name",
            "description" => "New description"
          })
        )
      end)

      params = %{name: "Updated Name", description: "New description"}
      assert {:ok, item} = Items.update("item-123", params, config: config)
      assert item["name"] == "Updated Name"
    end
  end

  describe "delete/2" do
    test "deletes an item", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "DELETE", "/api/v1/items/item-123", fn conn ->
        conn |> Plug.Conn.resp(204, "")
      end)

      assert :ok = Items.delete("item-123", config: config)
    end

    test "returns not_found for non-existent item", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "DELETE", "/api/v1/items/not-found", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(404, Jason.encode!(%{"error" => "Not found"}))
      end)

      assert {:error, %Error{type: :not_found}} = Items.delete("not-found", config: config)
    end
  end

  describe "get_published_items/2" do
    test "returns published items for a resource", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/items/item-123/publisheditems", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "data" => [
              %{"id" => "pub-1", "spaceId" => "space-1"},
              %{"id" => "pub-2", "spaceId" => "space-2"}
            ]
          })
        )
      end)

      assert {:ok, %{"data" => items}} = Items.get_published_items("item-123", config: config)
      assert length(items) == 2
    end
  end

  describe "get_collections/2" do
    test "returns collections containing the item", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/items/item-123/collections", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "data" => [
              %{"id" => "coll-1", "name" => "Favorites"},
              %{"id" => "coll-2", "name" => "Work"}
            ]
          })
        )
      end)

      assert {:ok, %{"data" => collections}} = Items.get_collections("item-123", config: config)
      assert length(collections) == 2
    end
  end
end
