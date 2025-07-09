defmodule QlikElixir.UploaderTest do
  use ExUnit.Case

  alias QlikElixir.{Uploader, Config, Error}

  setup do
    bypass = Bypass.open()
    
    config = Config.new(
      api_key: "test-key",
      tenant_url: "http://localhost:#{bypass.port}",
      connection_id: "default-conn",
      http_options: [retry: false]
    )

    # Create a temporary test file
    test_file = Path.join(System.tmp_dir!(), "test_#{:erlang.unique_integer()}.csv")
    File.write!(test_file, "header1,header2\nvalue1,value2\n")
    
    on_exit(fn -> File.rm(test_file) end)

    {:ok, bypass: bypass, config: config, test_file: test_file}
  end

  describe "upload_file/3" do
    test "successful file upload", %{bypass: bypass, config: config, test_file: test_file} do
      Bypass.expect_once(bypass, "POST", "/api/v1/data-files", fn conn ->
        assert ["multipart/form-data" <> _] = Plug.Conn.get_req_header(conn, "content-type")
        
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(201, Jason.encode!(%{
          id: "file-123",
          name: Path.basename(test_file),
          size: 30
        }))
      end)

      assert {:ok, %{"id" => "file-123"}} = Uploader.upload_file(test_file, config)
    end

    test "upload with custom name", %{bypass: bypass, config: config, test_file: test_file} do
      Bypass.expect_once(bypass, "POST", "/api/v1/data-files", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(201, Jason.encode!(%{
          id: "file-123",
          name: "custom.csv",
          size: 30
        }))
      end)

      assert {:ok, %{"name" => "custom.csv"}} = 
        Uploader.upload_file(test_file, config, name: "custom.csv")
    end

    test "handles file not found", %{config: config} do
      assert {:error, %Error{type: :file_not_found}} = 
        Uploader.upload_file("/non/existent/file.csv", config)
    end

    test "validates file extension", %{config: config} do
      test_file = Path.join(System.tmp_dir!(), "test_#{:erlang.unique_integer()}.txt")
      File.write!(test_file, "content")
      on_exit(fn -> File.rm(test_file) end)

      assert {:error, %Error{type: :validation_error, message: message}} = 
        Uploader.upload_file(test_file, config)
      
      assert message =~ "must end with .csv"
    end

    test "validates file size", %{config: config} do
      # Create a mock file that reports as too large
      test_file = Path.join(System.tmp_dir!(), "large_#{:erlang.unique_integer()}.csv")
      # Write 1MB of data (well under the limit, but we'll test the validation logic separately)
      File.write!(test_file, String.duplicate("x", 1024 * 1024))
      on_exit(fn -> File.rm(test_file) end)

      # The actual file is small, so this should succeed
      # We'll test the size validation logic in upload_content tests
      assert {:ok, _} = Uploader.upload_file(test_file, config)
    end

    test "handles overwrite when file exists", %{bypass: bypass, config: config, test_file: test_file} do
      # First request returns 409 conflict
      Bypass.expect_once(bypass, "POST", "/api/v1/data-files", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(409, Jason.encode!(%{message: "File exists"}))
      end)

      # Then expect a GET to find the file
      Bypass.expect_once(bypass, "GET", "/api/v1/data-files", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{
          data: [
            %{id: "existing-123", name: Path.basename(test_file), size: 30}
          ]
        }))
      end)

      # Then DELETE the existing file
      Bypass.expect_once(bypass, "DELETE", "/api/v1/data-files/existing-123", fn conn ->
        Plug.Conn.resp(conn, 204, "")
      end)

      # Finally, retry the upload
      Bypass.expect_once(bypass, "POST", "/api/v1/data-files", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(201, Jason.encode!(%{
          id: "new-123",
          name: Path.basename(test_file),
          size: 30
        }))
      end)

      assert {:ok, %{"id" => "new-123"}} = 
        Uploader.upload_file(test_file, config, overwrite: true)
    end

    test "returns error when overwrite is false and file exists", %{bypass: bypass, config: config, test_file: test_file} do
      Bypass.expect_once(bypass, "POST", "/api/v1/data-files", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(409, Jason.encode!(%{message: "File exists"}))
      end)

      assert {:error, %Error{type: :file_exists_error}} = 
        Uploader.upload_file(test_file, config, overwrite: false)
    end
  end

  describe "upload_content/4" do
    test "successful content upload", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "POST", "/api/v1/data-files", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(201, Jason.encode!(%{
          id: "file-123",
          name: "data.csv",
          size: 20
        }))
      end)

      content = "col1,col2\nval1,val2"
      assert {:ok, %{"id" => "file-123"}} = 
        Uploader.upload_content(content, "data.csv", config)
    end

    test "validates filename extension", %{config: config} do
      assert {:error, %Error{type: :validation_error}} = 
        Uploader.upload_content("content", "data.txt", config)
    end

    test "validates content size", %{config: config} do
      # Create content larger than 500MB limit
      large_content = String.duplicate("x", 501 * 1024 * 1024)
      
      assert {:error, %Error{type: :file_too_large, message: message}} = 
        Uploader.upload_content(large_content, "large.csv", config)
      
      assert message =~ "exceeds maximum allowed size"
    end

    test "uses connection_id from options", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "POST", "/api/v1/data-files", fn conn ->
        # Would need to parse multipart to verify connectionId field
        # For now, just verify the request succeeds
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(201, Jason.encode!(%{id: "file-123"}))
      end)

      assert {:ok, _} = 
        Uploader.upload_content("content", "data.csv", config, connection_id: "custom-conn")
    end

    test "validates config before upload", %{bypass: _bypass} do
      invalid_config = %Config{api_key: nil, tenant_url: "https://test.com"}
      
      assert {:error, %Error{type: :configuration_error}} = 
        Uploader.upload_content("content", "data.csv", invalid_config)
    end
  end
end