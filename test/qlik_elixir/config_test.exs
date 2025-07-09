defmodule QlikElixir.ConfigTest do
  use ExUnit.Case
  doctest QlikElixir.Config

  alias QlikElixir.Config

  describe "new/1" do
    test "creates config from options" do
      config = Config.new(
        api_key: "test-key",
        tenant_url: "https://test.qlikcloud.com",
        connection_id: "conn-123"
      )

      assert config.api_key == "test-key"
      assert config.tenant_url == "https://test.qlikcloud.com"
      assert config.connection_id == "conn-123"
    end

    test "creates config with custom http options" do
      config = Config.new(
        api_key: "test-key",
        tenant_url: "https://test.qlikcloud.com",
        http_options: [timeout: 1000]
      )

      assert config.http_options[:timeout] == 1000
    end

    test "falls back to environment variables" do
      System.put_env("QLIK_API_KEY", "env-key")
      System.put_env("QLIK_TENANT_URL", "https://env.qlikcloud.com")
      System.put_env("QLIK_CONNECTION_ID", "env-conn")

      config = Config.new()

      assert config.api_key == "env-key"
      assert config.tenant_url == "https://env.qlikcloud.com"
      assert config.connection_id == "env-conn"

      # Cleanup
      System.delete_env("QLIK_API_KEY")
      System.delete_env("QLIK_TENANT_URL")
      System.delete_env("QLIK_CONNECTION_ID")
    end
  end

  describe "validate/1" do
    test "validates valid config" do
      config = Config.new(
        api_key: "test-key",
        tenant_url: "https://test.qlikcloud.com"
      )

      assert {:ok, ^config} = Config.validate(config)
    end

    test "returns error for missing api_key" do
      config = %Config{tenant_url: "https://test.qlikcloud.com"}

      assert {:error, error} = Config.validate(config)
      assert error.type == :configuration_error
      assert error.message == "API key is required"
    end

    test "returns error for empty api_key" do
      config = %Config{api_key: "", tenant_url: "https://test.qlikcloud.com"}

      assert {:error, error} = Config.validate(config)
      assert error.type == :configuration_error
      assert error.message == "API key cannot be empty"
    end

    test "returns error for missing tenant_url" do
      config = %Config{api_key: "test-key"}

      assert {:error, error} = Config.validate(config)
      assert error.type == :configuration_error
      assert error.message == "Tenant URL is required"
    end

    test "returns error for empty tenant_url" do
      config = %Config{api_key: "test-key", tenant_url: ""}

      assert {:error, error} = Config.validate(config)
      assert error.type == :configuration_error
      assert error.message == "Tenant URL cannot be empty"
    end

    test "returns error for invalid tenant_url" do
      config = %Config{api_key: "test-key", tenant_url: "not-a-url"}

      assert {:error, error} = Config.validate(config)
      assert error.type == :configuration_error
      assert error.message =~ "Invalid tenant URL"
    end

    test "accepts http and https URLs" do
      http_config = %Config{api_key: "test-key", tenant_url: "http://test.qlikcloud.com"}
      https_config = %Config{api_key: "test-key", tenant_url: "https://test.qlikcloud.com"}

      assert {:ok, _} = Config.validate(http_config)
      assert {:ok, _} = Config.validate(https_config)
    end
  end

  describe "merge/2" do
    test "merges options with existing config" do
      config = Config.new(
        api_key: "original-key",
        tenant_url: "https://original.qlikcloud.com",
        connection_id: "original-conn"
      )

      merged = Config.merge(config, 
        api_key: "new-key",
        connection_id: "new-conn"
      )

      assert merged.api_key == "new-key"
      assert merged.tenant_url == "https://original.qlikcloud.com"
      assert merged.connection_id == "new-conn"
    end

    test "merges http options" do
      config = Config.new(http_options: [timeout: 1000, retry: true])
      merged = Config.merge(config, http_options: [timeout: 2000])

      assert merged.http_options[:timeout] == 2000
      assert merged.http_options[:retry] == true
    end
  end

  describe "base_url/1" do
    test "returns base URL without trailing slash" do
      config = %Config{tenant_url: "https://test.qlikcloud.com/"}
      assert Config.base_url(config) == "https://test.qlikcloud.com"
    end

    test "returns base URL as is if no trailing slash" do
      config = %Config{tenant_url: "https://test.qlikcloud.com"}
      assert Config.base_url(config) == "https://test.qlikcloud.com"
    end
  end

  describe "headers/1" do
    test "returns authorization and content-type headers" do
      config = %Config{api_key: "test-key"}
      headers = Config.headers(config)

      assert {"Authorization", "Bearer test-key"} in headers
      assert {"Content-Type", "application/json"} in headers
    end
  end
end