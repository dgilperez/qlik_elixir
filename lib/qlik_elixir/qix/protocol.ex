defmodule QlikElixir.QIX.Protocol do
  @moduledoc """
  JSON-RPC protocol handling for Qlik Engine API.

  The Qlik Engine API uses JSON-RPC 2.0 over WebSocket.

  ## Message Format

  Request:
  ```json
  {
    "jsonrpc": "2.0",
    "id": 1,
    "method": "ClassName.Method",
    "handle": 0,
    "params": [...]
  }
  ```

  Response:
  ```json
  {
    "jsonrpc": "2.0",
    "id": 1,
    "result": {...}
  }
  ```

  Error:
  ```json
  {
    "jsonrpc": "2.0",
    "id": 1,
    "error": {"code": -32602, "message": "Invalid params"}
  }
  ```

  ## Handles

  - `0` = Global object (used for OpenDoc, GetActiveDoc, etc.)
  - App handle = returned from OpenDoc (e.g., `1`)
  - Object handle = returned from GetObject (e.g., `2`, `3`, etc.)
  """

  @default_page_height 1000
  @default_page_width 100

  @doc """
  Encodes a JSON-RPC request.

  Returns `{:ok, json_string, request_id}`.
  """
  @spec encode_request(String.t(), non_neg_integer(), list(), pos_integer()) ::
          {:ok, String.t(), pos_integer()}
  def encode_request(method, handle, params, request_id) do
    message = %{
      "jsonrpc" => "2.0",
      "id" => request_id,
      "method" => method,
      "handle" => handle,
      "params" => params
    }

    {:ok, Jason.encode!(message), request_id}
  end

  @doc """
  Decodes a JSON-RPC response.

  Returns:
  - `{:ok, %{id: id, result: result}}` for successful responses
  - `{:error, %{id: id, code: code, message: message}}` for error responses
  - `{:error, :invalid_json}` for malformed JSON
  - `{:error, :invalid_protocol}` for non-JSON-RPC messages
  """
  @spec decode_response(String.t()) ::
          {:ok, map()} | {:error, map()} | {:error, atom()}
  def decode_response(json) do
    case Jason.decode(json) do
      {:ok, %{"jsonrpc" => "2.0", "id" => id} = response} ->
        decode_result(response, id)

      {:ok, _} ->
        {:error, :invalid_protocol}

      {:error, _} ->
        {:error, :invalid_json}
    end
  end

  defp decode_result(%{"error" => error}, id) do
    {:error, %{id: id, code: error["code"], message: error["message"]}}
  end

  defp decode_result(%{"result" => result}, id) do
    {:ok, %{id: id, result: result}}
  end

  defp decode_result(_response, id) do
    {:ok, %{id: id, result: nil}}
  end

  # Request builders

  @doc """
  Builds params for Global.OpenDoc request.
  """
  @spec build_open_doc(String.t()) :: list(map())
  def build_open_doc(app_id) do
    [%{"qDocName" => app_id}]
  end

  @doc """
  Builds params for Doc.GetAllSheets request.
  """
  @spec build_get_all_sheets() :: list()
  def build_get_all_sheets do
    []
  end

  @doc """
  Builds params for Doc.GetObject request.
  """
  @spec build_get_object(String.t()) :: list(map())
  def build_get_object(object_id) do
    [%{"qId" => object_id}]
  end

  @doc """
  Builds params for GenericObject.GetLayout request.
  """
  @spec build_get_layout() :: list()
  def build_get_layout do
    []
  end

  @doc """
  Builds params for GenericObject.GetHyperCubeData request.

  ## Parameters

    * `path` - Path to the hypercube definition (usually "/qHyperCubeDef")
    * `pages` - List of page requests (defaults to first 1000 rows)

  """
  @spec build_get_hypercube_data(String.t(), list(map())) :: list()
  def build_get_hypercube_data(path, []) do
    default_page = %{
      "qTop" => 0,
      "qLeft" => 0,
      "qHeight" => @default_page_height,
      "qWidth" => @default_page_width
    }

    [path, [default_page]]
  end

  def build_get_hypercube_data(path, pages) do
    converted_pages =
      Enum.map(pages, fn page ->
        %{
          "qTop" => page[:qTop] || 0,
          "qLeft" => page[:qLeft] || 0,
          "qHeight" => page[:qHeight] || @default_page_height,
          "qWidth" => page[:qWidth] || @default_page_width
        }
      end)

    [path, converted_pages]
  end

  # Response extractors

  @doc """
  Extracts the qHandle from an OpenDoc or GetObject response.
  """
  @spec extract_handle(map() | nil) :: {:ok, non_neg_integer()} | {:error, :no_handle}
  def extract_handle(nil), do: {:error, :no_handle}

  def extract_handle(%{"qReturn" => %{"qHandle" => handle}}) when is_integer(handle) do
    {:ok, handle}
  end

  def extract_handle(_), do: {:error, :no_handle}

  @doc """
  Extracts sheet list from GetAllSheets response.
  """
  @spec extract_sheets(map()) :: {:ok, list(map())}
  def extract_sheets(%{"qList" => sheets}) when is_list(sheets) do
    {:ok, sheets}
  end

  def extract_sheets(_), do: {:ok, []}

  @doc """
  Extracts hypercube data matrix from GetHyperCubeData response.
  """
  @spec extract_hypercube_data(map()) :: {:ok, list(list())}
  def extract_hypercube_data(%{"qDataPages" => [%{"qMatrix" => matrix} | _]})
      when is_list(matrix) do
    {:ok, matrix}
  end

  def extract_hypercube_data(_), do: {:ok, []}
end
