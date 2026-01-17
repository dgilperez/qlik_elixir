defmodule QlikElixir.REST.DataConnectionsTest do
  use ExUnit.Case

  alias QlikElixir.{Config, Error}
  alias QlikElixir.REST.DataConnections

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
    test "returns list of data connections", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/data-connections", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            data: [
              %{id: "conn-1", qName: "DataFiles", qType: "folder"},
              %{id: "conn-2", qName: "PostgreSQL", qType: "PostgreSQL"}
            ]
          })
        )
      end)

      assert {:ok, %{"data" => connections}} = DataConnections.list(config: config)
      assert length(connections) == 2
    end

    test "supports pagination", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/data-connections", fn conn ->
        assert conn.query_string =~ "limit=50"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{data: []}))
      end)

      assert {:ok, _} = DataConnections.list(config: config, limit: 50)
    end

    test "supports space_id filter", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/data-connections", fn conn ->
        assert conn.query_string =~ "spaceId=space-123"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{data: []}))
      end)

      assert {:ok, _} = DataConnections.list(config: config, space_id: "space-123")
    end

    test "supports name filter", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/data-connections", fn conn ->
        assert conn.query_string =~ "name=DataFiles"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{data: []}))
      end)

      assert {:ok, _} = DataConnections.list(config: config, name: "DataFiles")
    end

    test "supports type filter", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/data-connections", fn conn ->
        assert conn.query_string =~ "qType=folder"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{data: []}))
      end)

      assert {:ok, _} = DataConnections.list(config: config, qType: "folder")
    end
  end

  describe "get/2" do
    test "returns connection details", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/data-connections/conn-123", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            id: "conn-123",
            qName: "DataFiles",
            qType: "folder",
            qConnectStatement: "CUSTOM CONNECT TO \"provider=DataFiles;\"",
            spaceId: "space-456"
          })
        )
      end)

      assert {:ok, connection} = DataConnections.get("conn-123", config: config)
      assert connection["id"] == "conn-123"
      assert connection["qName"] == "DataFiles"
    end

    test "returns error for missing connection", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/data-connections/missing", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(404, Jason.encode!(%{message: "Not found"}))
      end)

      assert {:error, %Error{type: :not_found}} = DataConnections.get("missing", config: config)
    end
  end

  describe "create/2" do
    test "creates a new data connection", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "POST", "/api/v1/data-connections", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)
        assert params["qName"] == "NewConnection"
        assert params["qType"] == "PostgreSQL"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          201,
          Jason.encode!(%{
            id: "new-conn",
            qName: "NewConnection",
            qType: "PostgreSQL"
          })
        )
      end)

      params = %{
        qName: "NewConnection",
        qType: "PostgreSQL",
        qConnectStatement: "CONNECT TO 'Provider=PostgreSQL;...';"
      }
      assert {:ok, connection} = DataConnections.create(params, config: config)
      assert connection["id"] == "new-conn"
    end
  end

  describe "update/3" do
    test "updates connection details", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "PATCH", "/api/v1/data-connections/conn-123", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)
        assert params["qName"] == "Updated Name"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            id: "conn-123",
            qName: "Updated Name",
            qType: "folder"
          })
        )
      end)

      assert {:ok, connection} = DataConnections.update("conn-123", %{qName: "Updated Name"}, config: config)
      assert connection["qName"] == "Updated Name"
    end
  end

  describe "delete/2" do
    test "deletes a data connection", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "DELETE", "/api/v1/data-connections/conn-123", fn conn ->
        Plug.Conn.resp(conn, 204, "")
      end)

      assert :ok = DataConnections.delete("conn-123", config: config)
    end

    test "returns error for missing connection", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "DELETE", "/api/v1/data-connections/missing", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(404, Jason.encode!(%{message: "Not found"}))
      end)

      assert {:error, %Error{type: :not_found}} = DataConnections.delete("missing", config: config)
    end
  end

  describe "duplicate/2" do
    test "duplicates a data connection", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "POST", "/api/v1/data-connections/conn-123/actions/duplicate", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          201,
          Jason.encode!(%{
            id: "conn-copy",
            qName: "DataFiles (Copy)",
            qType: "folder"
          })
        )
      end)

      assert {:ok, connection} = DataConnections.duplicate("conn-123", config: config)
      assert connection["id"] == "conn-copy"
    end

    test "supports custom name", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "POST", "/api/v1/data-connections/conn-123/actions/duplicate", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)
        assert params["qName"] == "Custom Name"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(201, Jason.encode!(%{id: "conn-copy", qName: "Custom Name"}))
      end)

      assert {:ok, _} = DataConnections.duplicate("conn-123", config: config, name: "Custom Name")
    end

    test "supports target space", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "POST", "/api/v1/data-connections/conn-123/actions/duplicate", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)
        assert params["spaceId"] == "space-789"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(201, Jason.encode!(%{id: "conn-copy", spaceId: "space-789"}))
      end)

      assert {:ok, _} = DataConnections.duplicate("conn-123", config: config, space_id: "space-789")
    end
  end

  describe "batch_delete/2" do
    test "deletes multiple connections", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "POST", "/api/v1/data-connections/actions/delete", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)
        assert params["ids"] == ["conn-1", "conn-2", "conn-3"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{deletedIds: ["conn-1", "conn-2", "conn-3"]}))
      end)

      assert {:ok, result} = DataConnections.batch_delete(["conn-1", "conn-2", "conn-3"], config: config)
      assert result["deletedIds"] == ["conn-1", "conn-2", "conn-3"]
    end
  end

  describe "batch_update/2" do
    test "updates multiple connections", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "PATCH", "/api/v1/data-connections", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)
        assert length(params["updates"]) == 2

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            data: [
              %{id: "conn-1", qName: "Updated 1"},
              %{id: "conn-2", qName: "Updated 2"}
            ]
          })
        )
      end)

      updates = [
        %{id: "conn-1", qName: "Updated 1"},
        %{id: "conn-2", qName: "Updated 2"}
      ]
      assert {:ok, %{"data" => updated}} = DataConnections.batch_update(updates, config: config)
      assert length(updated) == 2
    end
  end

  describe "change_space/3" do
    test "moves connection to another space", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "POST", "/api/v1/data-connections/conn-123/actions/change-space", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)
        assert params["spaceId"] == "space-456"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{id: "conn-123", spaceId: "space-456"}))
      end)

      assert {:ok, connection} = DataConnections.change_space("conn-123", "space-456", config: config)
      assert connection["spaceId"] == "space-456"
    end
  end

  describe "change_owner/3" do
    test "changes connection owner", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "POST", "/api/v1/data-connections/conn-123/actions/change-owner", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)
        assert params["ownerId"] == "user-789"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{id: "conn-123", ownerId: "user-789"}))
      end)

      assert {:ok, connection} = DataConnections.change_owner("conn-123", "user-789", config: config)
      assert connection["ownerId"] == "user-789"
    end
  end
end
