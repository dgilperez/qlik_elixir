defmodule QlikElixir.REST.CollectionsTest do
  use ExUnit.Case, async: true

  alias QlikElixir.REST.Collections
  alias QlikElixir.{Config, Error}

  setup do
    bypass = Bypass.open()
    config = Config.new(api_key: "test-key", tenant_url: "http://localhost:#{bypass.port}")
    {:ok, bypass: bypass, config: config}
  end

  describe "list/1" do
    test "returns paginated collections", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/collections", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "data" => [
              %{"id" => "coll-1", "name" => "Favorites", "type" => "private"},
              %{"id" => "coll-2", "name" => "Shared Reports", "type" => "public"}
            ],
            "links" => %{}
          })
        )
      end)

      assert {:ok, %{"data" => collections}} = Collections.list(config: config)
      assert length(collections) == 2
    end

    test "supports pagination", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/collections", fn conn ->
        assert conn.query_string =~ "limit=10"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{"data" => [], "links" => %{}}))
      end)

      assert {:ok, _} = Collections.list(config: config, limit: 10)
    end

    test "supports name filter", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/collections", fn conn ->
        assert conn.query_string =~ "name=Favorites"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{"data" => [], "links" => %{}}))
      end)

      assert {:ok, _} = Collections.list(config: config, name: "Favorites")
    end

    test "supports type filter", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/collections", fn conn ->
        assert conn.query_string =~ "type=public"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{"data" => [], "links" => %{}}))
      end)

      assert {:ok, _} = Collections.list(config: config, type: "public")
    end

    test "supports sort parameter", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/collections", fn conn ->
        assert conn.query_string =~ "sort=-createdAt"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{"data" => [], "links" => %{}}))
      end)

      assert {:ok, _} = Collections.list(config: config, sort: "-createdAt")
    end
  end

  describe "get/2" do
    test "returns collection by ID", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/collections/coll-123", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "id" => "coll-123",
            "name" => "My Collection",
            "type" => "private",
            "description" => "A collection of apps",
            "ownerId" => "user-abc",
            "itemCount" => 5,
            "createdAt" => "2024-01-01T00:00:00Z",
            "updatedAt" => "2024-01-15T00:00:00Z"
          })
        )
      end)

      assert {:ok, coll} = Collections.get("coll-123", config: config)
      assert coll["id"] == "coll-123"
      assert coll["itemCount"] == 5
    end

    test "returns not_found for non-existent collection", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/collections/not-found", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(404, Jason.encode!(%{"error" => "Not found"}))
      end)

      assert {:error, %Error{type: :not_found}} = Collections.get("not-found", config: config)
    end
  end

  describe "create/2" do
    test "creates a new collection", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "POST", "/api/v1/collections", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)
        assert params["name"] == "New Collection"
        assert params["type"] == "private"
        assert params["description"] == "My new collection"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          201,
          Jason.encode!(%{
            "id" => "coll-new",
            "name" => "New Collection",
            "type" => "private"
          })
        )
      end)

      params = %{name: "New Collection", type: "private", description: "My new collection"}
      assert {:ok, coll} = Collections.create(params, config: config)
      assert coll["id"] == "coll-new"
    end
  end

  describe "update/3" do
    test "updates a collection", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "PUT", "/api/v1/collections/coll-123", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)
        assert params["name"] == "Updated Collection"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "id" => "coll-123",
            "name" => "Updated Collection"
          })
        )
      end)

      assert {:ok, coll} = Collections.update("coll-123", %{name: "Updated Collection"}, config: config)
      assert coll["name"] == "Updated Collection"
    end
  end

  describe "delete/2" do
    test "deletes a collection", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "DELETE", "/api/v1/collections/coll-123", fn conn ->
        conn |> Plug.Conn.resp(204, "")
      end)

      assert :ok = Collections.delete("coll-123", config: config)
    end

    test "returns not_found for non-existent collection", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "DELETE", "/api/v1/collections/not-found", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(404, Jason.encode!(%{"error" => "Not found"}))
      end)

      assert {:error, %Error{type: :not_found}} = Collections.delete("not-found", config: config)
    end
  end

  describe "list_items/2" do
    test "returns items in a collection", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/collections/coll-123/items", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "data" => [
              %{"id" => "item-1", "name" => "App 1"},
              %{"id" => "item-2", "name" => "App 2"}
            ],
            "links" => %{}
          })
        )
      end)

      assert {:ok, %{"data" => items}} = Collections.list_items("coll-123", config: config)
      assert length(items) == 2
    end

    test "supports pagination", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/collections/coll-123/items", fn conn ->
        assert conn.query_string =~ "limit=5"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{"data" => [], "links" => %{}}))
      end)

      assert {:ok, _} = Collections.list_items("coll-123", config: config, limit: 5)
    end
  end

  describe "add_items/3" do
    test "adds items to a collection", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "POST", "/api/v1/collections/coll-123/items", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)
        assert params["items"] == ["item-1", "item-2"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "data" => [
              %{"id" => "item-1", "collectionId" => "coll-123"},
              %{"id" => "item-2", "collectionId" => "coll-123"}
            ]
          })
        )
      end)

      assert {:ok, result} = Collections.add_items("coll-123", ["item-1", "item-2"], config: config)
      assert length(result["data"]) == 2
    end
  end

  describe "remove_item/3" do
    test "removes an item from a collection", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "DELETE", "/api/v1/collections/coll-123/items/item-456", fn conn ->
        conn |> Plug.Conn.resp(204, "")
      end)

      assert :ok = Collections.remove_item("coll-123", "item-456", config: config)
    end
  end

  describe "get_favorites/1" do
    test "returns favorites collection", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/collections/favorites", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "id" => "favorites",
            "name" => "Favorites",
            "type" => "favorite",
            "itemCount" => 10
          })
        )
      end)

      assert {:ok, favorites} = Collections.get_favorites(config: config)
      assert favorites["type"] == "favorite"
    end
  end
end
