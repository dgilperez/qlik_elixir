defmodule QlikElixirTest do
  use ExUnit.Case
  doctest QlikElixir

  setup do
    bypass = Bypass.open()
    
    # Set environment variables for testing
    System.put_env("QLIK_API_KEY", "test-key")
    System.put_env("QLIK_TENANT_URL", "http://localhost:#{bypass.port}")
    System.put_env("QLIK_CONNECTION_ID", "test-conn")

    # Create a test CSV file
    test_file = Path.join(System.tmp_dir!(), "test_#{:erlang.unique_integer()}.csv")
    File.write!(test_file, "id,name\n1,John\n2,Jane\n")
    
    on_exit(fn -> 
      File.rm(test_file)
      System.delete_env("QLIK_API_KEY")
      System.delete_env("QLIK_TENANT_URL")
      System.delete_env("QLIK_CONNECTION_ID")
    end)

    {:ok, bypass: bypass, test_file: test_file}
  end

  describe "upload_csv/2" do
    test "uploads a file successfully", %{bypass: bypass, test_file: test_file} do
      Bypass.expect_once(bypass, "POST", "/api/v1/data-files", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(201, Jason.encode!(%{
          id: "file-123",
          name: Path.basename(test_file),
          size: 24
        }))
      end)

      assert {:ok, %{"id" => "file-123"}} = QlikElixir.upload_csv(test_file)
    end

    test "uploads with custom name", %{bypass: bypass, test_file: test_file} do
      Bypass.expect_once(bypass, "POST", "/api/v1/data-files", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(201, Jason.encode!(%{
          id: "file-123",
          name: "custom.csv"
        }))
      end)

      assert {:ok, %{"name" => "custom.csv"}} = 
        QlikElixir.upload_csv(test_file, name: "custom.csv")
    end

    test "uses custom config", %{bypass: bypass, test_file: test_file} do
      custom_config = QlikElixir.new_config(
        api_key: "custom-key",
        tenant_url: "http://localhost:#{bypass.port}"
      )

      Bypass.expect_once(bypass, "POST", "/api/v1/data-files", fn conn ->
        assert ["Bearer custom-key"] = Plug.Conn.get_req_header(conn, "authorization")
        
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(201, Jason.encode!(%{id: "file-123"}))
      end)

      assert {:ok, _} = QlikElixir.upload_csv(test_file, config: custom_config)
    end
  end

  describe "upload_csv_content/3" do
    test "uploads content successfully", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/api/v1/data-files", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(201, Jason.encode!(%{
          id: "file-123",
          name: "dynamic.csv",
          size: 20
        }))
      end)

      content = "col1,col2\nval1,val2"
      assert {:ok, %{"id" => "file-123"}} = 
        QlikElixir.upload_csv_content(content, "dynamic.csv")
    end

    test "handles overwrite option", %{bypass: bypass} do
      # First call returns conflict
      Bypass.expect_once(bypass, "POST", "/api/v1/data-files", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(409, Jason.encode!(%{message: "File exists"}))
      end)

      # Find existing file
      Bypass.expect_once(bypass, "GET", "/api/v1/data-files", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{
          data: [%{id: "existing-123", name: "dynamic.csv"}]
        }))
      end)

      # Delete existing
      Bypass.expect_once(bypass, "DELETE", "/api/v1/data-files/existing-123", fn conn ->
        Plug.Conn.resp(conn, 204, "")
      end)

      # Retry upload
      Bypass.expect_once(bypass, "POST", "/api/v1/data-files", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(201, Jason.encode!(%{id: "new-123"}))
      end)

      assert {:ok, %{"id" => "new-123"}} = 
        QlikElixir.upload_csv_content("content", "dynamic.csv", overwrite: true)
    end
  end

  describe "list_files/1" do
    test "lists files successfully", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/api/v1/data-files", fn conn ->
        assert conn.query_string == "limit=100&offset=0"
        
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{
          data: [
            %{id: "file-1", name: "data1.csv", size: 100},
            %{id: "file-2", name: "data2.csv", size: 200}
          ],
          total: 2
        }))
      end)

      assert {:ok, %{"data" => files, "total" => 2}} = QlikElixir.list_files()
      assert length(files) == 2
    end

    test "lists files with pagination", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/api/v1/data-files", fn conn ->
        assert conn.query_string == "limit=10&offset=20"
        
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{data: [], total: 50}))
      end)

      assert {:ok, _} = QlikElixir.list_files(limit: 10, offset: 20)
    end
  end

  describe "delete_file/2" do
    test "deletes file successfully", %{bypass: bypass} do
      Bypass.expect_once(bypass, "DELETE", "/api/v1/data-files/file-123", fn conn ->
        Plug.Conn.resp(conn, 204, "")
      end)

      assert :ok = QlikElixir.delete_file("file-123")
    end

    test "returns error for non-existent file", %{bypass: bypass} do
      Bypass.expect_once(bypass, "DELETE", "/api/v1/data-files/non-existent", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(404, Jason.encode!(%{message: "Not found"}))
      end)

      assert {:error, %QlikElixir.Error{type: :file_not_found}} = 
        QlikElixir.delete_file("non-existent")
    end
  end

  describe "file_exists?/2" do
    test "returns true when file exists", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/api/v1/data-files", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{
          data: [
            %{id: "file-1", name: "exists.csv", size: 100},
            %{id: "file-2", name: "other.csv", size: 200}
          ]
        }))
      end)

      assert QlikElixir.file_exists?("exists.csv") == true
    end

    test "returns false when file doesn't exist", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/api/v1/data-files", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{
          data: [
            %{id: "file-1", name: "other.csv", size: 100}
          ]
        }))
      end)

      assert QlikElixir.file_exists?("not-exists.csv") == false
    end

    test "returns false on API error", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/api/v1/data-files", fn conn ->
        Plug.Conn.resp(conn, 500, "Server error")
      end)

      assert QlikElixir.file_exists?("any.csv") == false
    end
  end

  describe "find_file_by_name/2" do
    test "finds existing file", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/api/v1/data-files", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{
          data: [
            %{id: "file-1", name: "target.csv", size: 100},
            %{id: "file-2", name: "other.csv", size: 200}
          ]
        }))
      end)

      assert {:ok, %{"id" => "file-1", "name" => "target.csv"}} = 
        QlikElixir.find_file_by_name("target.csv")
    end

    test "returns error when file not found", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/api/v1/data-files", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{data: []}))
      end)

      assert {:error, %QlikElixir.Error{type: :file_not_found}} = 
        QlikElixir.find_file_by_name("missing.csv")
    end
  end
end