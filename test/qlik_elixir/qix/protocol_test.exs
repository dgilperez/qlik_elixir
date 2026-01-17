defmodule QlikElixir.QIX.ProtocolTest do
  use ExUnit.Case

  alias QlikElixir.QIX.Protocol

  describe "encode_request/4" do
    test "encodes a basic request" do
      {:ok, json, 1} = Protocol.encode_request("Global.OpenDoc", 0, [%{qDocName: "app-123"}], 1)

      decoded = Jason.decode!(json)
      assert decoded["jsonrpc"] == "2.0"
      assert decoded["id"] == 1
      assert decoded["method"] == "Global.OpenDoc"
      assert decoded["handle"] == 0
      assert decoded["params"] == [%{"qDocName" => "app-123"}]
    end

    test "auto-increments request id" do
      {:ok, _, id1} = Protocol.encode_request("Test", 0, [], 1)
      {:ok, _, id2} = Protocol.encode_request("Test", 0, [], id1 + 1)

      assert id2 == id1 + 1
    end

    test "handles empty params" do
      {:ok, json, _} = Protocol.encode_request("GetAllSheets", 1, [], 1)

      decoded = Jason.decode!(json)
      assert decoded["params"] == []
    end
  end

  describe "decode_response/1" do
    test "decodes a successful response" do
      json =
        Jason.encode!(%{
          jsonrpc: "2.0",
          id: 1,
          result: %{
            qReturn: %{qType: "Doc", qHandle: 1, qGenericId: "app-123"}
          }
        })

      assert {:ok, %{id: 1, result: result}} = Protocol.decode_response(json)
      assert result["qReturn"]["qHandle"] == 1
    end

    test "decodes an error response" do
      json =
        Jason.encode!(%{
          jsonrpc: "2.0",
          id: 1,
          error: %{
            code: -32_602,
            message: "Invalid params",
            parameter: "qDocName"
          }
        })

      assert {:error, %{id: 1, code: -32_602, message: "Invalid params"}} = Protocol.decode_response(json)
    end

    test "handles malformed JSON" do
      assert {:error, :invalid_json} = Protocol.decode_response("not json")
    end

    test "handles missing jsonrpc field" do
      json = Jason.encode!(%{id: 1, result: %{}})

      assert {:error, :invalid_protocol} = Protocol.decode_response(json)
    end
  end

  describe "build_open_doc/1" do
    test "creates OpenDoc request params" do
      params = Protocol.build_open_doc("app-123")

      assert params == [%{"qDocName" => "app-123"}]
    end
  end

  describe "build_get_all_sheets/0" do
    test "creates GetAllSheets request with empty params" do
      params = Protocol.build_get_all_sheets()

      assert params == []
    end
  end

  describe "build_get_object/1" do
    test "creates GetObject request params" do
      params = Protocol.build_get_object("chart-abc")

      assert params == [%{"qId" => "chart-abc"}]
    end
  end

  describe "build_get_layout/0" do
    test "creates GetLayout request with empty params" do
      params = Protocol.build_get_layout()

      assert params == []
    end
  end

  describe "build_get_hypercube_data/2" do
    test "creates GetHyperCubeData request params with defaults" do
      params = Protocol.build_get_hypercube_data("/qHyperCubeDef", [])

      assert [path, pages] = params
      assert path == "/qHyperCubeDef"
      assert [page] = pages
      assert page["qTop"] == 0
      assert page["qLeft"] == 0
      assert page["qHeight"] == 1000
      assert page["qWidth"] == 100
    end

    test "creates GetHyperCubeData request params with custom page" do
      pages = [%{qTop: 100, qLeft: 0, qHeight: 500, qWidth: 10}]
      params = Protocol.build_get_hypercube_data("/qHyperCubeDef", pages)

      assert [_, request_pages] = params
      assert [page] = request_pages
      assert page["qTop"] == 100
      assert page["qHeight"] == 500
    end
  end

  describe "extract_handle/1" do
    test "extracts qHandle from result" do
      result = %{"qReturn" => %{"qHandle" => 42, "qType" => "Doc"}}

      assert {:ok, 42} = Protocol.extract_handle(result)
    end

    test "returns error when handle missing" do
      result = %{"qReturn" => %{"qType" => "Doc"}}

      assert {:error, :no_handle} = Protocol.extract_handle(result)
    end

    test "handles nil result" do
      assert {:error, :no_handle} = Protocol.extract_handle(nil)
    end
  end

  describe "extract_sheets/1" do
    test "extracts sheet list from GetAllSheets result" do
      result = %{
        "qList" => [
          %{"qInfo" => %{"qId" => "sheet1"}, "qMeta" => %{"title" => "Sales"}},
          %{"qInfo" => %{"qId" => "sheet2"}, "qMeta" => %{"title" => "KPIs"}}
        ]
      }

      assert {:ok, sheets} = Protocol.extract_sheets(result)
      assert length(sheets) == 2
      assert Enum.at(sheets, 0)["qInfo"]["qId"] == "sheet1"
    end

    test "returns empty list when no sheets" do
      result = %{"qList" => []}

      assert {:ok, []} = Protocol.extract_sheets(result)
    end
  end

  describe "extract_hypercube_data/1" do
    test "extracts data matrix from result" do
      result = %{
        "qDataPages" => [
          %{
            "qMatrix" => [
              [%{"qText" => "A"}, %{"qNum" => 100}],
              [%{"qText" => "B"}, %{"qNum" => 200}]
            ]
          }
        ]
      }

      assert {:ok, data} = Protocol.extract_hypercube_data(result)
      assert length(data) == 2
      assert Enum.at(data, 0) == [%{"qText" => "A"}, %{"qNum" => 100}]
    end

    test "handles empty data" do
      result = %{"qDataPages" => [%{"qMatrix" => []}]}

      assert {:ok, []} = Protocol.extract_hypercube_data(result)
    end
  end
end
