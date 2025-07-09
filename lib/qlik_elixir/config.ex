defmodule QlikElixir.Config do
  @moduledoc """
  Configuration management for QlikElixir.

  Supports configuration through:
  - Environment variables: QLIK_API_KEY, QLIK_TENANT_URL, QLIK_CONNECTION_ID
  - Runtime configuration
  - Application configuration
  """

  defstruct [:api_key, :tenant_url, :connection_id, :http_options]

  @type t :: %__MODULE__{
          api_key: String.t(),
          tenant_url: String.t(),
          connection_id: String.t() | nil,
          http_options: keyword()
        }

  @default_http_options [
    timeout: :timer.minutes(5),
    retry: :transient,
    max_retries: 3,
    retry_delay: fn attempt -> attempt * 1000 end
  ]

  @doc """
  Creates a new configuration struct.

  ## Examples

      iex> QlikElixir.Config.new(api_key: "key", tenant_url: "https://tenant.qlikcloud.com")
      %QlikElixir.Config{api_key: "key", tenant_url: "https://tenant.qlikcloud.com"}

  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      api_key: get_config_value(:api_key, opts),
      tenant_url: get_config_value(:tenant_url, opts),
      connection_id: get_config_value(:connection_id, opts),
      http_options: Keyword.get(opts, :http_options, @default_http_options)
    }
  end

  @doc """
  Validates a configuration struct.

  Returns {:ok, config} if valid, or {:error, reason} if invalid.
  """
  @spec validate(t()) :: {:ok, t()} | {:error, QlikElixir.Error.t()}
  def validate(%__MODULE__{} = config) do
    with :ok <- validate_api_key(config.api_key),
         :ok <- validate_tenant_url(config.tenant_url) do
      {:ok, config}
    end
  end

  @doc """
  Gets the default configuration.
  """
  @spec default() :: t()
  def default do
    new()
  end

  @doc """
  Merges configuration options with defaults.
  """
  @spec merge(t(), keyword()) :: t()
  def merge(%__MODULE__{} = config, opts) do
    %{config |
      api_key: opts[:api_key] || config.api_key,
      tenant_url: opts[:tenant_url] || config.tenant_url,
      connection_id: opts[:connection_id] || config.connection_id,
      http_options: Keyword.merge(config.http_options, opts[:http_options] || [])
    }
  end

  @doc """
  Gets the base URL for API requests.
  """
  @spec base_url(t()) :: String.t()
  def base_url(%__MODULE__{tenant_url: tenant_url}) do
    String.trim_trailing(tenant_url, "/")
  end

  @doc """
  Gets the headers for API requests.
  """
  @spec headers(t()) :: [{String.t(), String.t()}]
  def headers(%__MODULE__{api_key: api_key}) do
    [
      {"Authorization", "Bearer #{api_key}"},
      {"Content-Type", "application/json"}
    ]
  end

  defp get_config_value(key, opts) do
    opts[key] || env_value(key) || app_value(key)
  end

  defp env_value(:api_key), do: System.get_env("QLIK_API_KEY")
  defp env_value(:tenant_url), do: System.get_env("QLIK_TENANT_URL")
  defp env_value(:connection_id), do: System.get_env("QLIK_CONNECTION_ID")

  defp app_value(key) do
    Application.get_env(:qlik_elixir, key)
  end

  defp validate_api_key(nil) do
    {:error, QlikElixir.Error.configuration_error("API key is required")}
  end

  defp validate_api_key("") do
    {:error, QlikElixir.Error.configuration_error("API key cannot be empty")}
  end

  defp validate_api_key(_), do: :ok

  defp validate_tenant_url(nil) do
    {:error, QlikElixir.Error.configuration_error("Tenant URL is required")}
  end

  defp validate_tenant_url("") do
    {:error, QlikElixir.Error.configuration_error("Tenant URL cannot be empty")}
  end

  defp validate_tenant_url(url) do
    case URI.parse(url) do
      %URI{scheme: scheme, host: host} when scheme in ["http", "https"] and not is_nil(host) ->
        :ok

      _ ->
        {:error, QlikElixir.Error.configuration_error("Invalid tenant URL: #{url}")}
    end
  end
end