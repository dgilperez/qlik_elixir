defmodule QlikElixir.REST.NaturalLanguageTest do
  use ExUnit.Case, async: true

  alias QlikElixir.Config
  alias QlikElixir.REST.NaturalLanguage

  setup do
    bypass = Bypass.open()
    config = Config.new(api_key: "test-key", tenant_url: "http://localhost:#{bypass.port}")
    {:ok, bypass: bypass, config: config}
  end

  describe "recommend/3" do
    test "returns recommendations for text query", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "POST", "/api/v1/apps/app-123/insight-analyses/actions/recommend", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)
        assert params["text"] == "show sales by region"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "data" => [
              %{
                "type" => "breakdown",
                "analysis" => %{
                  "title" => "Sales by Region",
                  "fields" => ["Sales", "Region"]
                }
              }
            ]
          })
        )
      end)

      assert {:ok, response} = NaturalLanguage.recommend("app-123", %{"text" => "show sales by region"}, config: config)
      assert length(response["data"]) == 1
    end

    test "supports field-based recommendations", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "POST", "/api/v1/apps/app-123/insight-analyses/actions/recommend", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)
        assert length(params["fields"]) == 2

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{"data" => []}))
      end)

      request = %{
        "fields" => [
          %{"name" => "Sales", "type" => "measure"},
          %{"name" => "Region", "type" => "dimension"}
        ]
      }

      assert {:ok, _} = NaturalLanguage.recommend("app-123", request, config: config)
    end

    test "supports target_analysis parameter", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "POST", "/api/v1/apps/app-123/insight-analyses/actions/recommend", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)
        assert params["targetAnalysis"] == "trend"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{"data" => []}))
      end)

      request = %{"text" => "show trend", "targetAnalysis" => "trend"}
      assert {:ok, _} = NaturalLanguage.recommend("app-123", request, config: config)
    end
  end

  describe "ask/3" do
    test "delegates to recommend with text query", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "POST", "/api/v1/apps/app-123/insight-analyses/actions/recommend", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)
        assert params["text"] == "What were the total sales?"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "data" => [
              %{
                "type" => "fact",
                "analysis" => %{
                  "title" => "Total Sales",
                  "narrative" => "Total sales were $1.5M"
                }
              }
            ]
          })
        )
      end)

      assert {:ok, response} = NaturalLanguage.ask("app-123", "What were the total sales?", config: config)
      assert length(response["data"]) == 1
    end
  end

  describe "list_analysis_types/2" do
    test "returns available analysis types for an app", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/apps/app-123/insight-analyses", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "data" => [
              %{
                "type" => "breakdown",
                "shortDescription" => "Break down a measure by a dimension",
                "longDescription" => "Shows how a measure is distributed across dimension values"
              },
              %{
                "type" => "trend",
                "shortDescription" => "Show trend over time",
                "longDescription" => "Analyzes how a measure changes over a time period"
              },
              %{
                "type" => "comparison",
                "shortDescription" => "Compare values",
                "longDescription" => "Compare measure values across dimension members"
              }
            ]
          })
        )
      end)

      assert {:ok, response} = NaturalLanguage.list_analysis_types("app-123", config: config)
      assert length(response["data"]) == 3
    end
  end

  describe "get_model/2" do
    test "returns NL model info with fields and master items", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/apps/app-123/insight-analyses/model", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "data" => %{
              "fields" => [
                %{"name" => "Sales", "defaultAggregation" => "sum", "classifications" => ["measure"]},
                %{"name" => "Region", "defaultAggregation" => "countDistinct", "classifications" => ["dimension"]},
                %{"name" => "Date", "defaultAggregation" => "countDistinct", "classifications" => ["date"]}
              ],
              "masterItems" => [
                %{"caption" => "Total Sales", "libId" => "abc123", "classifications" => ["measure"]}
              ],
              "isLogicalModelEnabled" => true
            }
          })
        )
      end)

      assert {:ok, response} = NaturalLanguage.get_model("app-123", config: config)
      assert length(response["data"]["fields"]) == 3
      assert length(response["data"]["masterItems"]) == 1
    end
  end
end
