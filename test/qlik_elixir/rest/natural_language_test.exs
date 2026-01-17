defmodule QlikElixir.REST.NaturalLanguageTest do
  use ExUnit.Case, async: true

  alias QlikElixir.Config
  alias QlikElixir.REST.NaturalLanguage

  setup do
    bypass = Bypass.open()
    config = Config.new(api_key: "test-key", tenant_url: "http://localhost:#{bypass.port}")
    {:ok, bypass: bypass, config: config}
  end

  describe "ask/3" do
    test "returns answer to a natural language question", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "POST", "/api/v1/apps/app-123/insight-analyses/actions/ask", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)
        assert params["text"] == "What were the total sales last month?"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "conversationId" => "conv-123",
            "responses" => [
              %{
                "type" => "narrative",
                "text" => "Total sales last month were $1.5M",
                "confidence" => 0.95
              },
              %{
                "type" => "chart",
                "chartType" => "bar",
                "data" => %{"qHyperCube" => %{}}
              }
            ],
            "followUps" => [
              "Show sales by region",
              "Compare to previous month"
            ]
          })
        )
      end)

      assert {:ok, response} = NaturalLanguage.ask("app-123", "What were the total sales last month?", config: config)
      assert response["conversationId"] == "conv-123"
      assert length(response["responses"]) == 2
      assert length(response["followUps"]) == 2
    end

    test "supports conversation context", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "POST", "/api/v1/apps/app-123/insight-analyses/actions/ask", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)
        assert params["conversationId"] == "conv-existing"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{"conversationId" => "conv-existing", "responses" => []}))
      end)

      assert {:ok, _} =
               NaturalLanguage.ask("app-123", "Show by region", config: config, conversation_id: "conv-existing")
    end

    test "supports language option", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "POST", "/api/v1/apps/app-123/insight-analyses/actions/ask", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)
        assert params["lang"] == "es"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{"conversationId" => "conv-123", "responses" => []}))
      end)

      assert {:ok, _} = NaturalLanguage.ask("app-123", "¿Cuáles fueron las ventas?", config: config, lang: "es")
    end
  end

  describe "get_recommendations/2" do
    test "returns analysis recommendations for an app", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/apps/app-123/insight-analyses/recommendations", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "recommendations" => [
              %{
                "id" => "rec-1",
                "text" => "Total Sales by Region",
                "description" => "View sales performance across regions",
                "fields" => ["Sales", "Region"]
              },
              %{
                "id" => "rec-2",
                "text" => "Monthly Trends",
                "description" => "Analyze sales trends over time",
                "fields" => ["Sales", "Date"]
              }
            ]
          })
        )
      end)

      assert {:ok, response} = NaturalLanguage.get_recommendations("app-123", config: config)
      assert length(response["recommendations"]) == 2
    end

    test "supports fields filter", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/apps/app-123/insight-analyses/recommendations", fn conn ->
        assert conn.query_string =~ "fields=Sales"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{"recommendations" => []}))
      end)

      assert {:ok, _} = NaturalLanguage.get_recommendations("app-123", config: config, fields: "Sales")
    end

    test "supports target filter", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/apps/app-123/insight-analyses/recommendations", fn conn ->
        assert conn.query_string =~ "target=analysis"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{"recommendations" => []}))
      end)

      assert {:ok, _} = NaturalLanguage.get_recommendations("app-123", config: config, target: "analysis")
    end
  end

  describe "get_fields/2" do
    test "returns available fields for NL analysis", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/apps/app-123/insight-analyses/fields", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "fields" => [
              %{"name" => "Sales", "type" => "measure", "tags" => ["$numeric"]},
              %{"name" => "Region", "type" => "dimension", "tags" => ["$ascii"]},
              %{"name" => "Date", "type" => "dimension", "tags" => ["$date"]}
            ]
          })
        )
      end)

      assert {:ok, response} = NaturalLanguage.get_fields("app-123", config: config)
      assert length(response["fields"]) == 3
    end
  end

  describe "get_model/2" do
    test "returns NL model info for an app", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/apps/app-123/insight-analyses/model", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "status" => "ready",
            "lastUpdated" => "2024-01-15T00:00:00Z",
            "languages" => ["en", "es", "de"],
            "vocabulary" => %{
              "terms" => 1500,
              "synonyms" => 200
            }
          })
        )
      end)

      assert {:ok, model} = NaturalLanguage.get_model("app-123", config: config)
      assert model["status"] == "ready"
      assert "en" in model["languages"]
    end
  end
end
