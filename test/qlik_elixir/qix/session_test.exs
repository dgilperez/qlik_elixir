defmodule QlikElixir.QIX.SessionTest do
  use ExUnit.Case, async: true

  alias QlikElixir.Config
  alias QlikElixir.QIX.Session

  describe "connect/2" do
    test "returns error when no config provided" do
      assert {:error, %QlikElixir.Error{type: :configuration_error}} =
               Session.connect("app-123", [])
    end

    test "requires app_id parameter" do
      config = Config.new(api_key: "key", tenant_url: "https://tenant.qlik.com")
      assert {:error, %QlikElixir.Error{type: :validation_error}} = Session.connect(nil, config: config)
      assert {:error, %QlikElixir.Error{type: :validation_error}} = Session.connect("", config: config)
    end
  end

  describe "request/4" do
    test "validates session is running" do
      # Non-existent session
      assert {:error, %QlikElixir.Error{type: :network_error}} =
               Session.request(:not_a_pid, "Global.OpenDoc", 0, [])
    end
  end

  describe "disconnect/1" do
    test "handles invalid session gracefully" do
      assert :ok = Session.disconnect(:not_a_pid)
    end
  end

  describe "protocol integration" do
    test "encode_request creates valid JSON-RPC message" do
      {:ok, json, id} =
        QlikElixir.QIX.Protocol.encode_request("Global.OpenDoc", 0, [%{"qDocName" => "app-123"}], 1)

      assert id == 1
      decoded = Jason.decode!(json)
      assert decoded["jsonrpc"] == "2.0"
      assert decoded["id"] == 1
      assert decoded["method"] == "Global.OpenDoc"
      assert decoded["handle"] == 0
      assert decoded["params"] == [%{"qDocName" => "app-123"}]
    end

    test "decode_response parses successful response" do
      json = ~s({"jsonrpc":"2.0","id":1,"result":{"qReturn":{"qHandle":1}}})

      assert {:ok, %{id: 1, result: %{"qReturn" => %{"qHandle" => 1}}}} =
               QlikElixir.QIX.Protocol.decode_response(json)
    end

    test "decode_response parses error response" do
      json = ~s({"jsonrpc":"2.0","id":1,"error":{"code":-32602,"message":"Invalid params"}})

      assert {:error, %{id: 1, code: -32_602, message: "Invalid params"}} =
               QlikElixir.QIX.Protocol.decode_response(json)
    end
  end

  describe "build_websocket_url/2" do
    test "builds correct websocket URL for app" do
      config = Config.new(api_key: "key", tenant_url: "https://tenant.qlik.com")
      url = Session.build_websocket_url("app-123", config)
      assert url == "wss://tenant.qlik.com/app/app-123"
    end

    test "handles trailing slash in tenant URL" do
      config = Config.new(api_key: "key", tenant_url: "https://tenant.qlik.com/")
      url = Session.build_websocket_url("app-123", config)
      assert url == "wss://tenant.qlik.com/app/app-123"
    end

    test "handles http scheme" do
      config = Config.new(api_key: "key", tenant_url: "http://localhost:9076")
      url = Session.build_websocket_url("app-123", config)
      assert url == "ws://localhost:9076/app/app-123"
    end
  end

  describe "parse_websocket_url/1" do
    test "parses wss URL correctly" do
      {:ok, host, port, path} = Session.parse_websocket_url("wss://tenant.qlik.com/app/123")
      assert host == ~c"tenant.qlik.com"
      assert port == 443
      assert path == "/app/123"
    end

    test "parses ws URL correctly" do
      {:ok, host, port, path} = Session.parse_websocket_url("ws://localhost:9076/app/123")
      assert host == ~c"localhost"
      assert port == 9076
      assert path == "/app/123"
    end

    test "returns error for invalid URL" do
      assert {:error, _} = Session.parse_websocket_url("not-a-url")
    end
  end
end
