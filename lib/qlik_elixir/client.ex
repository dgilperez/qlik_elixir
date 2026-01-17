defmodule QlikElixir.Client do
  @moduledoc """
  HTTP client wrapper for Qlik API interactions.
  """

  alias QlikElixir.{Config, Error}

  @doc """
  Makes a GET request to the Qlik API.
  """
  @spec get(String.t(), Config.t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def get(path, config, opts \\ []) do
    url = build_url(config, path)
    headers = Config.headers(config)

    request(:get, url, headers, nil, config, opts)
  end

  @doc """
  Makes a POST request to the Qlik API.
  """
  @spec post(String.t(), map() | {:multipart, list()}, Config.t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def post(path, body, config, opts \\ []) do
    url = build_url(config, path)

    case body do
      {:multipart, _parts} ->
        # For multipart, don't set Content-Type header (Req will set it with boundary)
        headers = [{"Authorization", "Bearer #{config.api_key}"}]
        request(:post, url, headers, body, config, opts)

      _ ->
        headers = Config.headers(config)
        request(:post, url, headers, body, config, opts)
    end
  end

  @doc """
  Makes a PUT request to the Qlik API.
  """
  @spec put(String.t(), map(), Config.t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def put(path, body, config, opts \\ []) do
    url = build_url(config, path)
    headers = Config.headers(config)

    request(:put, url, headers, body, config, opts)
  end

  @doc """
  Makes a PATCH request to the Qlik API.
  """
  @spec patch(String.t(), map(), Config.t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def patch(path, body, config, opts \\ []) do
    url = build_url(config, path)
    headers = Config.headers(config)

    request(:patch, url, headers, body, config, opts)
  end

  @doc """
  Makes a DELETE request to the Qlik API.
  """
  @spec delete(String.t(), Config.t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def delete(path, config, opts \\ []) do
    url = build_url(config, path)
    headers = Config.headers(config)

    request(:delete, url, headers, nil, config, opts)
  end

  defp request(method, url, headers, body, config, opts) do
    req_opts = build_req_options(method, url, headers, body, config, opts)

    case Req.request(req_opts) do
      {:ok, %{status: status, body: response_body}} when status in 200..299 ->
        {:ok, response_body}

      {:ok, %{status: 409, body: body}} ->
        {:error, Error.file_exists_error("File already exists", details: body)}

      {:ok, %{status: 401}} ->
        {:error, Error.authentication_error("Invalid API key or unauthorized access")}

      {:ok, %{status: 403, body: body}} ->
        message = extract_error_message(body, "Access forbidden")
        {:error, Error.authorization_error(message, details: body)}

      {:ok, %{status: 404, body: body}} ->
        {:error, Error.file_not_found("Resource not found", details: body)}

      {:ok, %{status: status, body: body}} ->
        message = extract_error_message(body, "Request failed with status #{status}")
        {:error, Error.upload_error(message, response: %{status: status, body: body})}

      {:error, exception} ->
        {:error, Error.network_error("Network request failed: #{inspect(exception)}")}
    end
  end

  defp build_req_options(method, url, headers, body, config, opts) do
    base_opts = [
      method: method,
      url: url,
      headers: headers
    ]

    base_opts
    |> add_body(body)
    |> Keyword.merge(config.http_options)
    |> Keyword.merge(opts)
  end

  defp add_body(opts, nil), do: opts
  defp add_body(opts, {:multipart, parts}), do: Keyword.put(opts, :form_multipart, parts)
  defp add_body(opts, body) when is_map(body), do: Keyword.put(opts, :json, body)
  defp add_body(opts, body), do: Keyword.put(opts, :body, body)

  defp build_url(%Config{} = config, path) do
    base = Config.base_url(config)
    path = String.trim_leading(path, "/")
    "#{base}/#{path}"
  end

  defp extract_error_message(body, default) when is_map(body) do
    body["message"] || body["error"] || body["errors"] || default
  end

  defp extract_error_message(_, default), do: default
end
