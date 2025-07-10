defmodule QlikElixir.MultipartFixTest do
  use ExUnit.Case

  alias QlikElixir.{Uploader, Config}

  test "multipart format is compatible with Req expectations" do
    bypass = Bypass.open()

    config =
      Config.new(
        api_key: "test-key",
        tenant_url: "http://localhost:#{bypass.port}",
        connection_id: "test-conn"
      )

    # Test that verifies the fix for multipart format
    # The key changes were:
    # 1. In uploader.ex: {"file", {content, [filename: filename, content_type: "text/csv"]}}
    #    Instead of the incorrect: {:file, content, [options]}
    # 2. In client.ex: Using :form_multipart option (already correct)

    Bypass.expect_once(bypass, "POST", "/api/v1/data-files", fn conn ->
      # Verify we get multipart/form-data content type
      assert ["multipart/form-data" <> _] = Plug.Conn.get_req_header(conn, "content-type")

      {:ok, body, conn} = Plug.Conn.read_body(conn)

      # Verify the multipart body has correct structure
      # Should have string keys, not atoms
      assert body =~ ~s(name="file")
      assert body =~ ~s(name="connectionId")

      # File part should have filename and content-type
      assert body =~ ~s(filename="test.csv")
      assert body =~ "content-type: text/csv"

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(201, Jason.encode!(%{"id" => "success"}))
    end)

    content = "id,name\n1,test"

    assert {:ok, %{"id" => "success"}} =
             Uploader.upload_content(content, "test.csv", config)
  end
end
