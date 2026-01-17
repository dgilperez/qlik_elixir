defmodule QlikElixir.QIX.AppTest do
  use ExUnit.Case

  alias QlikElixir.QIX.App

  describe "list_sheets/1" do
    test "returns sheets from GetAllSheets response" do
      # Mock response structure
      result = %{
        "qList" => [
          %{"qInfo" => %{"qId" => "sheet1"}, "qMeta" => %{"title" => "Sales"}},
          %{"qInfo" => %{"qId" => "sheet2"}, "qMeta" => %{"title" => "KPIs"}}
        ]
      }

      assert {:ok, sheets} = App.parse_sheets_response({:ok, result})
      assert length(sheets) == 2
      assert hd(sheets)["qInfo"]["qId"] == "sheet1"
    end

    test "returns empty list when no sheets" do
      result = %{"qList" => []}
      assert {:ok, []} = App.parse_sheets_response({:ok, result})
    end

    test "propagates errors" do
      error = {:error, %QlikElixir.Error{type: :network_error}}
      assert {:error, _} = App.parse_sheets_response(error)
    end
  end

  describe "list_objects/2" do
    test "returns objects from sheet layout" do
      # Sheet layout response contains child objects
      result = %{
        "qLayout" => %{
          "qChildList" => %{
            "qItems" => [
              %{"qInfo" => %{"qId" => "obj1", "qType" => "barchart"}},
              %{"qInfo" => %{"qId" => "obj2", "qType" => "linechart"}}
            ]
          }
        }
      }

      assert {:ok, objects} = App.parse_objects_response({:ok, result})
      assert length(objects) == 2
      assert hd(objects)["qInfo"]["qId"] == "obj1"
    end

    test "returns empty list when no objects" do
      result = %{"qLayout" => %{"qChildList" => %{"qItems" => []}}}
      assert {:ok, []} = App.parse_objects_response({:ok, result})
    end
  end

  describe "get_layout/2" do
    test "returns object layout" do
      result = %{
        "qLayout" => %{
          "qInfo" => %{"qId" => "obj1", "qType" => "barchart"},
          "qHyperCube" => %{
            "qDimensionInfo" => [%{"qFallbackTitle" => "Country"}],
            "qMeasureInfo" => [%{"qFallbackTitle" => "Sales"}]
          }
        }
      }

      assert {:ok, layout} = App.parse_layout_response({:ok, result})
      assert layout["qInfo"]["qId"] == "obj1"
    end
  end

  describe "get_hypercube_data/3" do
    test "extracts data matrix from response" do
      result = %{
        "qDataPages" => [
          %{
            "qMatrix" => [
              [%{"qText" => "USA", "qNum" => "NaN"}, %{"qText" => "$1.2M", "qNum" => 1_200_000}],
              [%{"qText" => "Germany", "qNum" => "NaN"}, %{"qText" => "$900K", "qNum" => 900_000}]
            ],
            "qArea" => %{"qTop" => 0, "qLeft" => 0, "qHeight" => 2, "qWidth" => 2}
          }
        ]
      }

      assert {:ok, data} = App.parse_hypercube_response({:ok, result})
      assert length(data) == 2
      assert hd(data) == [%{"qText" => "USA", "qNum" => "NaN"}, %{"qText" => "$1.2M", "qNum" => 1_200_000}]
    end

    test "returns empty list for empty data" do
      result = %{"qDataPages" => [%{"qMatrix" => []}]}
      assert {:ok, []} = App.parse_hypercube_response({:ok, result})
    end
  end

  describe "format_hypercube_data/2" do
    test "formats data with headers" do
      layout = %{
        "qHyperCube" => %{
          "qDimensionInfo" => [%{"qFallbackTitle" => "Country"}],
          "qMeasureInfo" => [%{"qFallbackTitle" => "Sales"}]
        }
      }

      data = [
        [%{"qText" => "USA"}, %{"qText" => "$1.2M", "qNum" => 1_200_000}],
        [%{"qText" => "Germany"}, %{"qText" => "$900K", "qNum" => 900_000}]
      ]

      result = App.format_hypercube_data(data, layout)

      assert result.headers == ["Country", "Sales"]
      assert length(result.rows) == 2
      assert hd(result.rows).text == ["USA", "$1.2M"]
      assert hd(result.rows).values == ["USA", 1_200_000]
    end
  end

  describe "select_values params" do
    test "builds select values params correctly" do
      params = App.build_select_values_params("Country", ["USA", "Germany"])

      assert params == [
               "/qListObjectDef",
               [%{"qText" => "USA"}, %{"qText" => "Germany"}],
               false,
               false
             ]
    end
  end

  describe "evaluate params" do
    test "builds evaluate expression params correctly" do
      params = App.build_evaluate_params("Sum(Sales)")
      assert params == [%{"qExpression" => "Sum(Sales)"}]
    end
  end

  describe "build_get_field_params/1" do
    test "builds field params" do
      params = App.build_get_field_params("Country")
      assert params == [%{"qFieldName" => "Country"}]
    end
  end
end
