defmodule QlikElixir.ClientTest do
  use ExUnit.Case

  alias QlikElixir.{Client, Config, Error}

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

  describe "get/3" do
    test "successful GET request", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/data-files", fn conn ->
        assert_auth_header(conn, "test-key")

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{data: []}))
      end)

      assert {:ok, %{"data" => []}} = Client.get("api/v1/data-files", config)
    end

    test "handles 401 unauthorized", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/data-files", fn conn ->
        Plug.Conn.resp(conn, 401, "")
      end)

      assert {:error, %Error{type: :authentication_error}} =
               Client.get("api/v1/data-files", config)
    end

    test "handles 404 not found", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/data-files/123", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(404, Jason.encode!(%{message: "Not found"}))
      end)

      assert {:error, %Error{type: :file_not_found}} =
               Client.get("api/v1/data-files/123", config)
    end

    test "handles network errors", %{bypass: bypass, config: config} do
      Bypass.down(bypass)

      assert {:error, %Error{type: :network_error}} =
               Client.get("api/v1/data-files", config)
    end
  end

  describe "post/4" do
    test "successful POST request with JSON body", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "POST", "/api/v1/data-files", fn conn ->
        assert_auth_header(conn, "test-key")
        assert Plug.Conn.get_req_header(conn, "content-type") == ["application/json"]

        {:ok, body, conn} = Plug.Conn.read_body(conn)
        assert Jason.decode!(body) == %{"name" => "test.csv"}

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(201, Jason.encode!(%{id: "123", name: "test.csv"}))
      end)

      assert {:ok, %{"id" => "123", "name" => "test.csv"}} =
               Client.post("api/v1/data-files", %{name: "test.csv"}, config)
    end

    test "successful POST request with multipart body", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "POST", "/api/v1/data-files", fn conn ->
        assert_auth_header(conn, "test-key")
        assert ["multipart/form-data" <> _] = Plug.Conn.get_req_header(conn, "content-type")

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(201, Jason.encode!(%{id: "123", name: "test.csv"}))
      end)

      multipart = [
        {"file", {"content", filename: "test.csv", content_type: "text/csv"}}
      ]

      assert {:ok, %{"id" => "123", "name" => "test.csv"}} =
               Client.post("api/v1/data-files", {:multipart, multipart}, config)
    end

    test "handles 409 conflict", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "POST", "/api/v1/data-files", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(409, Jason.encode!(%{message: "File exists"}))
      end)

      assert {:error, %Error{type: :file_exists_error}} =
               Client.post("api/v1/data-files", %{}, config)
    end

    test "handles generic errors", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "POST", "/api/v1/data-files", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(500, Jason.encode!(%{error: "Internal error"}))
      end)

      assert {:error, %Error{type: :upload_error, message: "Internal error"}} =
               Client.post("api/v1/data-files", %{}, config)
    end
  end

  describe "put/4" do
    test "successful PUT request with JSON body", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "PUT", "/api/v1/apps/123", fn conn ->
        assert_auth_header(conn, "test-key")
        assert Plug.Conn.get_req_header(conn, "content-type") == ["application/json"]

        {:ok, body, conn} = Plug.Conn.read_body(conn)
        assert Jason.decode!(body) == %{"name" => "Updated App"}

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{id: "123", name: "Updated App"}))
      end)

      assert {:ok, %{"id" => "123", "name" => "Updated App"}} =
               Client.put("api/v1/apps/123", %{name: "Updated App"}, config)
    end

    test "handles 404 not found", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "PUT", "/api/v1/apps/123", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(404, Jason.encode!(%{message: "Not found"}))
      end)

      assert {:error, %Error{type: :file_not_found}} =
               Client.put("api/v1/apps/123", %{name: "Updated"}, config)
    end
  end

  describe "patch/4" do
    test "successful PATCH request with JSON body", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "PATCH", "/api/v1/spaces/456", fn conn ->
        assert_auth_header(conn, "test-key")
        assert Plug.Conn.get_req_header(conn, "content-type") == ["application/json"]

        {:ok, body, conn} = Plug.Conn.read_body(conn)
        assert Jason.decode!(body) == %{"description" => "New description"}

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{id: "456", description: "New description"}))
      end)

      assert {:ok, %{"id" => "456", "description" => "New description"}} =
               Client.patch("api/v1/spaces/456", %{description: "New description"}, config)
    end

    test "handles 403 forbidden", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "PATCH", "/api/v1/spaces/456", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(403, Jason.encode!(%{message: "Forbidden"}))
      end)

      assert {:error, %Error{type: :authorization_error}} =
               Client.patch("api/v1/spaces/456", %{}, config)
    end
  end

  describe "delete/3" do
    test "successful DELETE request", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "DELETE", "/api/v1/data-files/123", fn conn ->
        assert_auth_header(conn, "test-key")
        Plug.Conn.resp(conn, 204, "")
      end)

      assert {:ok, _} = Client.delete("api/v1/data-files/123", config)
    end

    test "handles DELETE errors", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "DELETE", "/api/v1/data-files/123", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(404, Jason.encode!(%{message: "Not found"}))
      end)

      assert {:error, %Error{type: :file_not_found}} =
               Client.delete("api/v1/data-files/123", config)
    end
  end

  defp assert_auth_header(conn, expected_key) do
    assert ["Bearer " <> ^expected_key] = Plug.Conn.get_req_header(conn, "authorization")
  end
end
