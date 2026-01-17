defmodule QlikElixir.REST.UsersTest do
  use ExUnit.Case

  alias QlikElixir.{Config, Error}
  alias QlikElixir.REST.Users

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
    test "returns list of users", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/users", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            data: [
              %{id: "user-1", name: "Alice", email: "alice@example.com"},
              %{id: "user-2", name: "Bob", email: "bob@example.com"}
            ]
          })
        )
      end)

      assert {:ok, %{"data" => users}} = Users.list(config: config)
      assert length(users) == 2
    end

    test "supports pagination", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/users", fn conn ->
        assert conn.query_string =~ "limit=50"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{data: []}))
      end)

      assert {:ok, _} = Users.list(config: config, limit: 50)
    end

    test "supports filter parameter", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/users", fn conn ->
        assert conn.query_string =~ "filter="

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{data: []}))
      end)

      assert {:ok, _} = Users.list(config: config, filter: "email eq \"test@example.com\"")
    end

    test "supports sort parameter", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/users", fn conn ->
        assert conn.query_string =~ "sort=name"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{data: []}))
      end)

      assert {:ok, _} = Users.list(config: config, sort: "name")
    end
  end

  describe "get/2" do
    test "returns user details", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/users/user-123", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            id: "user-123",
            name: "Alice",
            email: "alice@example.com",
            status: "active"
          })
        )
      end)

      assert {:ok, user} = Users.get("user-123", config: config)
      assert user["id"] == "user-123"
      assert user["name"] == "Alice"
    end

    test "returns error for missing user", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/users/missing", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(404, Jason.encode!(%{message: "Not found"}))
      end)

      assert {:error, %Error{type: :not_found}} = Users.get("missing", config: config)
    end
  end

  describe "me/1" do
    test "returns current user", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/users/me", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            id: "me-123",
            name: "Current User",
            email: "me@example.com"
          })
        )
      end)

      assert {:ok, user} = Users.me(config: config)
      assert user["id"] == "me-123"
    end
  end

  describe "create/2" do
    test "creates a new user", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "POST", "/api/v1/users", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)
        assert params["name"] == "New User"
        assert params["email"] == "new@example.com"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          201,
          Jason.encode!(%{
            id: "new-user",
            name: "New User",
            email: "new@example.com",
            status: "active"
          })
        )
      end)

      params = %{name: "New User", email: "new@example.com"}
      assert {:ok, user} = Users.create(params, config: config)
      assert user["id"] == "new-user"
    end
  end

  describe "update/3" do
    test "updates user details", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "PATCH", "/api/v1/users/user-123", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)
        assert params["name"] == "Updated Name"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            id: "user-123",
            name: "Updated Name",
            email: "alice@example.com"
          })
        )
      end)

      assert {:ok, user} = Users.update("user-123", %{name: "Updated Name"}, config: config)
      assert user["name"] == "Updated Name"
    end
  end

  describe "delete/2" do
    test "deletes a user", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "DELETE", "/api/v1/users/user-123", fn conn ->
        Plug.Conn.resp(conn, 204, "")
      end)

      assert :ok = Users.delete("user-123", config: config)
    end

    test "returns error for missing user", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "DELETE", "/api/v1/users/missing", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(404, Jason.encode!(%{message: "Not found"}))
      end)

      assert {:error, %Error{type: :not_found}} = Users.delete("missing", config: config)
    end
  end

  describe "count/1" do
    test "returns user count", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/users/actions/count", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{totalResults: 42}))
      end)

      assert {:ok, %{"totalResults" => 42}} = Users.count(config: config)
    end

    test "supports filter parameter", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/users/actions/count", fn conn ->
        assert conn.query_string =~ "filter="

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{totalResults: 5}))
      end)

      assert {:ok, _} = Users.count(config: config, filter: "status eq \"active\"")
    end
  end

  describe "filter/2" do
    test "filters users by query", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "POST", "/api/v1/users/actions/filter", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)
        assert params["filter"] == "email eq \"test@example.com\""

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            data: [%{id: "user-1", email: "test@example.com"}]
          })
        )
      end)

      assert {:ok, %{"data" => users}} =
               Users.filter("email eq \"test@example.com\"", config: config)

      assert length(users) == 1
    end
  end

  describe "invite/2" do
    test "invites users by email", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "POST", "/api/v1/users/actions/invite", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)
        assert params["emails"] == ["invite1@example.com", "invite2@example.com"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            invited: ["invite1@example.com", "invite2@example.com"]
          })
        )
      end)

      emails = ["invite1@example.com", "invite2@example.com"]
      assert {:ok, result} = Users.invite(emails, config: config)
      assert result["invited"] == emails
    end
  end
end
