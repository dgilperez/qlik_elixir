defmodule QlikElixir.REST.DataFilesTest do
  use ExUnit.Case

  alias QlikElixir.{Config, Error}
  alias QlikElixir.REST.DataFiles

  setup do
    bypass = Bypass.open()

    config =
      Config.new(
        api_key: "test-key",
        tenant_url: "http://localhost:#{bypass.port}",
        connection_id: "default-conn",
        http_options: [retry: false]
      )

    {:ok, bypass: bypass, config: config}
  end

  describe "list/1" do
    test "returns list of data files", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/data-files", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            data: [
              %{id: "file-1", name: "sales.csv", size: 1024},
              %{id: "file-2", name: "customers.csv", size: 2048}
            ]
          })
        )
      end)

      assert {:ok, %{"data" => files}} = DataFiles.list(config: config)
      assert length(files) == 2
    end

    test "supports connection_id filter", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/data-files", fn conn ->
        assert conn.query_string =~ "connectionId=conn-123"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{data: []}))
      end)

      assert {:ok, _} = DataFiles.list(config: config, connection_id: "conn-123")
    end

    test "supports pagination", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/data-files", fn conn ->
        assert conn.query_string =~ "limit=50"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{data: []}))
      end)

      assert {:ok, _} = DataFiles.list(config: config, limit: 50)
    end
  end

  describe "get/2" do
    test "returns file details", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/data-files/file-123", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            id: "file-123",
            name: "sales.csv",
            size: 1024,
            ownerId: "user-456"
          })
        )
      end)

      assert {:ok, file} = DataFiles.get("file-123", config: config)
      assert file["id"] == "file-123"
      assert file["name"] == "sales.csv"
    end

    test "returns error for missing file", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/data-files/missing", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(404, Jason.encode!(%{message: "Not found"}))
      end)

      assert {:error, %Error{type: :not_found}} = DataFiles.get("missing", config: config)
    end
  end

  describe "upload/3" do
    test "uploads content as a new file", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "POST", "/api/v1/data-files", fn conn ->
        assert ["multipart/form-data" <> _] = Plug.Conn.get_req_header(conn, "content-type")

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          201,
          Jason.encode!(%{
            id: "new-file",
            name: "data.csv",
            size: 20
          })
        )
      end)

      assert {:ok, file} = DataFiles.upload("col1,col2\nval1,val2", "data.csv", config: config)
      assert file["id"] == "new-file"
    end

    test "validates filename extension", %{config: config} do
      assert {:error, %Error{type: :validation_error}} =
               DataFiles.upload("content", "data.txt", config: config)
    end
  end

  describe "upload_file/2" do
    setup do
      test_file = Path.join(System.tmp_dir!(), "test_#{:erlang.unique_integer()}.csv")
      File.write!(test_file, "header1,header2\nvalue1,value2\n")
      on_exit(fn -> File.rm(test_file) end)

      {:ok, test_file: test_file}
    end

    test "uploads file from path", %{bypass: bypass, config: config, test_file: test_file} do
      Bypass.expect_once(bypass, "POST", "/api/v1/data-files", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          201,
          Jason.encode!(%{
            id: "file-123",
            name: Path.basename(test_file),
            size: 30
          })
        )
      end)

      assert {:ok, %{"id" => "file-123"}} = DataFiles.upload_file(test_file, config: config)
    end

    test "handles file not found", %{config: config} do
      assert {:error, %Error{type: :file_not_found}} =
               DataFiles.upload_file("/non/existent/file.csv", config: config)
    end
  end

  describe "update/3" do
    test "replaces file content", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "PUT", "/api/v1/data-files/file-123", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            id: "file-123",
            name: "sales.csv",
            size: 2048
          })
        )
      end)

      assert {:ok, file} = DataFiles.update("file-123", "new,content\nrow,data", config: config)
      assert file["size"] == 2048
    end
  end

  describe "delete/2" do
    test "deletes a file", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "DELETE", "/api/v1/data-files/file-123", fn conn ->
        Plug.Conn.resp(conn, 204, "")
      end)

      assert :ok = DataFiles.delete("file-123", config: config)
    end

    test "returns error for missing file", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "DELETE", "/api/v1/data-files/missing", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(404, Jason.encode!(%{message: "Not found"}))
      end)

      assert {:error, %Error{type: :not_found, message: "Data file not found"}} =
               DataFiles.delete("missing", config: config)
    end
  end

  describe "change_owner/3" do
    test "changes file owner", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "POST", "/api/v1/data-files/file-123/actions/change-owner", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)
        assert params["ownerId"] == "user-789"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{id: "file-123", ownerId: "user-789"}))
      end)

      assert {:ok, file} = DataFiles.change_owner("file-123", "user-789", config: config)
      assert file["ownerId"] == "user-789"
    end
  end

  describe "change_space/3" do
    test "moves file to another space", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "POST", "/api/v1/data-files/file-123/actions/change-space", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)
        assert params["spaceId"] == "space-456"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{id: "file-123", spaceId: "space-456"}))
      end)

      assert {:ok, file} = DataFiles.change_space("file-123", "space-456", config: config)
      assert file["spaceId"] == "space-456"
    end
  end

  describe "batch_delete/2" do
    test "deletes multiple files", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "POST", "/api/v1/data-files/actions/delete", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)
        assert params["ids"] == ["file-1", "file-2", "file-3"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{deletedIds: ["file-1", "file-2", "file-3"]}))
      end)

      assert {:ok, result} = DataFiles.batch_delete(["file-1", "file-2", "file-3"], config: config)
      assert result["deletedIds"] == ["file-1", "file-2", "file-3"]
    end
  end

  describe "batch_change_space/3" do
    test "moves multiple files to another space", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "POST", "/api/v1/data-files/actions/change-space", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)
        assert params["ids"] == ["file-1", "file-2"]
        assert params["spaceId"] == "space-456"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{movedIds: ["file-1", "file-2"]}))
      end)

      assert {:ok, result} = DataFiles.batch_change_space(["file-1", "file-2"], "space-456", config: config)
      assert result["movedIds"] == ["file-1", "file-2"]
    end
  end

  describe "get_quotas/1" do
    test "returns storage quotas", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/data-files/quotas", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            maxBytes: 10_737_418_240,
            usedBytes: 1_073_741_824
          })
        )
      end)

      assert {:ok, quotas} = DataFiles.get_quotas(config: config)
      assert quotas["maxBytes"] == 10_737_418_240
      assert quotas["usedBytes"] == 1_073_741_824
    end
  end

  describe "list_connections/1" do
    test "returns data connections", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/data-files/connections", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            data: [
              %{id: "conn-1", name: "Personal Files"},
              %{id: "conn-2", name: "Shared Data"}
            ]
          })
        )
      end)

      assert {:ok, %{"data" => connections}} = DataFiles.list_connections(config: config)
      assert length(connections) == 2
    end
  end

  describe "find_by_name/2" do
    test "finds file by name", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/data-files", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            data: [
              %{id: "file-123", name: "target.csv", size: 1024}
            ]
          })
        )
      end)

      assert {:ok, file} = DataFiles.find_by_name("target.csv", config: config)
      assert file["id"] == "file-123"
    end

    test "returns error when not found", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/data-files", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{data: []}))
      end)

      assert {:error, %Error{type: :file_not_found}} = DataFiles.find_by_name("missing.csv", config: config)
    end
  end
end
