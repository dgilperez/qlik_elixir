defmodule QlikElixir.REST.ReportTemplatesTest do
  use ExUnit.Case, async: true

  alias QlikElixir.{Config, Error}
  alias QlikElixir.REST.ReportTemplates

  setup do
    bypass = Bypass.open()
    config = Config.new(api_key: "test-key", tenant_url: "http://localhost:#{bypass.port}")
    {:ok, bypass: bypass, config: config}
  end

  defp json(conn, status, body) do
    conn
    |> Plug.Conn.put_resp_content_type("application/json")
    |> Plug.Conn.resp(status, Jason.encode!(body))
  end

  describe "list/1" do
    test "returns the templates", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/report-templates", fn conn ->
        json(conn, 200, %{
          "data" => [%{"id" => "tpl-1", "name" => "Ventas", "type" => "sense-excel-template"}],
          "links" => %{}
        })
      end)

      assert {:ok, %{"data" => [template]}} = ReportTemplates.list(config: config)
      assert template["name"] == "Ventas"
    end

    test "pages by offset and forwards the filters", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/report-templates", fn conn ->
        query = URI.decode_query(conn.query_string)

        assert query["limit"] == "50"
        assert query["skip"] == "100"
        assert query["name"] == "ventas"
        assert query["ownerId"] == "user-1"
        assert query["sourceAppId"] == "app-1"
        assert query["sort"] == "-updatedAt"
        refute Map.has_key?(query, "next")

        json(conn, 200, %{"data" => [], "links" => %{}})
      end)

      assert {:ok, _} =
               ReportTemplates.list(
                 config: config,
                 limit: 50,
                 skip: 100,
                 name: "ventas",
                 owner_id: "user-1",
                 source_app_id: "app-1",
                 sort: ["-updatedAt"]
               )
    end
  end

  describe "get/2" do
    test "returns a template by id", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/report-templates/tpl-1", fn conn ->
        json(conn, 200, %{"id" => "tpl-1", "name" => "Ventas"})
      end)

      assert {:ok, %{"id" => "tpl-1"}} = ReportTemplates.get("tpl-1", config: config)
    end

    test "returns not_found for an unknown template", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/report-templates/nope", fn conn ->
        json(conn, 404, %{"error" => "Not found"})
      end)

      assert {:error, %Error{type: :not_found}} = ReportTemplates.get("nope", config: config)
    end
  end

  describe "create/2" do
    test "maps snake_case params to the API body", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "POST", "/api/v1/report-templates", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)

        assert params == %{
                 "name" => "Ventas",
                 "description" => "Informe mensual",
                 "sourceAppId" => "app-1",
                 "temporaryContentId" => "tmp-1"
               }

        json(conn, 201, %{"id" => "tpl-new", "name" => "Ventas"})
      end)

      assert {:ok, %{"id" => "tpl-new"}} =
               ReportTemplates.create(
                 %{
                   name: "Ventas",
                   description: "Informe mensual",
                   source_app_id: "app-1",
                   temporary_content_id: "tmp-1"
                 },
                 config: config
               )
    end
  end

  describe "update/3" do
    test "replaces the template with PUT", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "PUT", "/api/v1/report-templates/tpl-1", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        assert Jason.decode!(body) == %{"name" => "Ventas 2026", "temporaryContentId" => "tmp-2"}

        json(conn, 201, %{"id" => "tpl-1", "name" => "Ventas 2026"})
      end)

      assert {:ok, %{"name" => "Ventas 2026"}} =
               ReportTemplates.update("tpl-1", %{name: "Ventas 2026", temporary_content_id: "tmp-2"}, config: config)
    end
  end

  describe "patch/3" do
    test "sends a JSON Patch document", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "PATCH", "/api/v1/report-templates/tpl-1", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        assert Jason.decode!(body) == [%{"op" => "replace", "path" => "/name", "value" => "Ventas 2026"}]

        Plug.Conn.resp(conn, 204, "")
      end)

      assert :ok =
               ReportTemplates.patch("tpl-1", [%{op: "replace", path: "/name", value: "Ventas 2026"}], config: config)
    end
  end

  describe "delete/2" do
    test "deletes the template", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "DELETE", "/api/v1/report-templates/tpl-1", fn conn ->
        Plug.Conn.resp(conn, 204, "")
      end)

      assert :ok = ReportTemplates.delete("tpl-1", config: config)
    end

    test "returns not_found for an unknown template", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "DELETE", "/api/v1/report-templates/nope", fn conn ->
        json(conn, 404, %{"error" => "Not found"})
      end)

      assert {:error, %Error{type: :not_found}} = ReportTemplates.delete("nope", config: config)
    end
  end

  describe "download/2" do
    test "posts to the download action and returns the bytes", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "POST", "/api/v1/report-templates/tpl-1/actions/download", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/octet-stream")
        |> Plug.Conn.resp(200, "PK\x03\x04 xlsx bytes")
      end)

      assert {:ok, "PK\x03\x04 xlsx bytes"} = ReportTemplates.download("tpl-1", config: config)
    end
  end
end
