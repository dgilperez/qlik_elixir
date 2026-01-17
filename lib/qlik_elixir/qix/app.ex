defmodule QlikElixir.QIX.App do
  @moduledoc """
  High-level API for interacting with Qlik apps via QIX Engine.

  This module provides user-friendly wrappers around the low-level Session
  and Protocol modules, making it easy to **extract data from Qlik visualizations**.

  ## API Reference

  - [QIX Engine Overview](https://qlik.dev/apis/json-rpc/qix/)
  - [Doc (App) API](https://qlik.dev/apis/json-rpc/qix/doc/)
  - [GenericObject API](https://qlik.dev/apis/json-rpc/qix/genericobject/)

  ## Features

  - **Navigation**: List sheets and visualization objects
  - **Data Extraction**: Get hypercube data from charts and tables
  - **Streaming**: Stream large datasets page by page
  - **Selections**: Filter data by making selections in fields
  - **Expressions**: Evaluate custom Qlik expressions

  ## Quick Start

      alias QlikElixir.QIX.{Session, App}

      # Connect to an app
      {:ok, session} = Session.connect("app-id", config: config)

      # List sheets
      {:ok, sheets} = App.list_sheets(session)

      # Get objects on a sheet
      {:ok, objects} = App.list_objects(session, sheet_id)

      # Extract data from a visualization (the main event!)
      {:ok, data} = App.get_hypercube_data(session, object_id)
      # Returns: %{headers: [...], rows: [...], total_rows: N}

      # Make selections to filter data
      :ok = App.select_values(session, "Country", ["USA", "Germany"])

      # Evaluate expressions
      {:ok, total} = App.evaluate(session, "Sum(Sales)")

      # Disconnect when done
      :ok = Session.disconnect(session)

  ## Data Format

  `get_hypercube_data/3` returns a structured result:

      %{
        headers: ["Country", "Sales", "Margin"],
        rows: [
          %{text: ["USA", "$1.2M", "23%"], values: ["USA", 1200000, 0.23]},
          %{text: ["Germany", "$900K", "19%"], values: ["Germany", 900000, 0.19]}
        ],
        total_rows: 50,
        truncated: false
      }

  ## Related Modules

  - `QlikElixir.QIX.Session` - WebSocket connection management
  - `QlikElixir.QIX.Protocol` - JSON-RPC protocol handling
  - `QlikElixir.REST.Apps` - REST API for app management
  """

  alias QlikElixir.Error
  alias QlikElixir.QIX.{Protocol, Session}

  @default_page_size 1000
  @default_max_rows 10_000

  # Data structures

  @type hypercube_result :: %{
          headers: [String.t()],
          rows: [%{text: [String.t()], values: [any()]}],
          total_rows: non_neg_integer(),
          truncated: boolean()
        }

  # Public API

  @doc """
  Lists all sheets in the connected app.

  ## Examples

      {:ok, sheets} = App.list_sheets(session)
      # Returns list of sheet objects with qInfo.qId, qMeta.title, etc.

  """
  @spec list_sheets(pid(), keyword()) :: {:ok, list(map())} | {:error, Error.t()}
  def list_sheets(session, opts \\ []) do
    # Use standard QIX GetObjects with qTypes filter instead of Sense mixin GetAllSheets
    params = %{
      "qOptions" => %{
        "qTypes" => ["sheet"],
        "qIncludeSessionObjects" => false,
        "qData" => %{}
      }
    }

    with {:ok, app_handle} <- Session.get_app_handle(session),
         result <- Session.request(session, "GetObjects", app_handle, params, opts) do
      parse_sheets_response(result)
    end
  end

  @doc """
  Lists visualization objects on a sheet.

  ## Examples

      {:ok, objects} = App.list_objects(session, "sheet-id")
      # Returns list of object info with qId, qType, etc.

  """
  @spec list_objects(pid(), String.t(), keyword()) :: {:ok, list(map())} | {:error, Error.t()}
  def list_objects(session, sheet_id, opts \\ []) do
    with {:ok, app_handle} <- Session.get_app_handle(session),
         {:ok, sheet_result} <-
           Session.request(session, "GetObject", app_handle, Protocol.build_get_object(sheet_id), opts),
         {:ok, sheet_handle} <- Protocol.extract_handle(sheet_result),
         result <- Session.request(session, "GetLayout", sheet_handle, [], opts) do
      parse_objects_response(result)
    end
  end

  @doc """
  Gets a visualization object by ID.

  Returns the object handle that can be used for further operations.

  ## Examples

      {:ok, object_handle} = App.get_object(session, "chart-id")

  """
  @spec get_object(pid(), String.t(), keyword()) :: {:ok, non_neg_integer()} | {:error, Error.t()}
  def get_object(session, object_id, opts \\ []) do
    with {:ok, app_handle} <- Session.get_app_handle(session),
         {:ok, result} <- Session.request(session, "GetObject", app_handle, Protocol.build_get_object(object_id), opts) do
      Protocol.extract_handle(result)
    end
  end

  @doc """
  Gets the layout of a visualization object.

  The layout contains hypercube definitions, dimension/measure info, etc.

  ## Examples

      {:ok, layout} = App.get_layout(session, object_handle)

  """
  @spec get_layout(pid(), non_neg_integer(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def get_layout(session, object_handle, opts \\ []) do
    session
    |> Session.request("GetLayout", object_handle, [], opts)
    |> parse_layout_response()
  end

  @doc """
  Extracts hypercube data from a visualization.

  This is the main function for getting data out of Qlik visualizations.

  ## Options

    * `:page_size` - Number of rows per page (default: 1000)
    * `:max_rows` - Maximum total rows to fetch (default: 10000)
    * `:path` - HyperCube path in layout (default: "/qHyperCubeDef")
    * `:format` - Return format: `:raw` or `:formatted` (default: `:formatted`)

  ## Examples

      # Get formatted data with headers
      {:ok, %{headers: ["Country", "Sales"], rows: [...]}} =
        App.get_hypercube_data(session, object_id)

      # Get raw matrix data
      {:ok, [[%{"qText" => "USA"}, ...]]} =
        App.get_hypercube_data(session, object_id, format: :raw)

  """
  @spec get_hypercube_data(pid(), String.t(), keyword()) ::
          {:ok, hypercube_result() | list()} | {:error, Error.t()}
  def get_hypercube_data(session, object_id, opts \\ []) do
    page_size = Keyword.get(opts, :page_size, @default_page_size)
    max_rows = Keyword.get(opts, :max_rows, @default_max_rows)
    path = Keyword.get(opts, :path, "/qHyperCubeDef")
    format = Keyword.get(opts, :format, :formatted)

    with {:ok, object_handle} <- get_object(session, object_id, opts),
         {:ok, layout} <- get_layout(session, object_handle, opts),
         {:ok, data} <- fetch_all_hypercube_pages(session, object_handle, path, page_size, max_rows, opts) do
      case format do
        :raw -> {:ok, data}
        :formatted -> {:ok, format_hypercube_data(data, layout["qLayout"] || layout)}
      end
    end
  end

  @doc """
  Streams hypercube data for large datasets.

  Returns a Stream that yields pages of data.

  ## Options

    * `:page_size` - Number of rows per page (default: 1000)
    * `:path` - HyperCube path in layout (default: "/qHyperCubeDef")

  ## Examples

      App.stream_hypercube_data(session, object_id)
      |> Stream.each(&process_page/1)
      |> Stream.run()

  """
  @spec stream_hypercube_data(pid(), String.t(), keyword()) :: Enumerable.t()
  def stream_hypercube_data(session, object_id, opts \\ []) do
    page_size = Keyword.get(opts, :page_size, @default_page_size)
    path = Keyword.get(opts, :path, "/qHyperCubeDef")

    Stream.resource(
      fn ->
        case get_object(session, object_id, opts) do
          {:ok, handle} -> {handle, 0}
          {:error, _} -> :error
        end
      end,
      fn
        :error ->
          {:halt, :error}

        {handle, top} ->
          page = [%{qTop: top, qLeft: 0, qHeight: page_size, qWidth: 100}]
          params = Protocol.build_get_hypercube_data(path, page)

          case Session.request(session, "GetHyperCubeData", handle, params, opts) do
            {:ok, result} ->
              case parse_hypercube_response({:ok, result}) do
                {:ok, []} -> {:halt, {handle, top}}
                {:ok, rows} -> {[rows], {handle, top + length(rows)}}
              end

            {:error, _} ->
              {:halt, {handle, top}}
          end
      end,
      fn _ -> :ok end
    )
  end

  @doc """
  Selects values in a field.

  ## Examples

      :ok = App.select_values(session, "Country", ["USA", "Germany"])

  """
  @spec select_values(pid(), String.t(), [String.t()], keyword()) :: :ok | {:error, Error.t()}
  def select_values(session, field_name, values, opts \\ []) when is_list(values) do
    with {:ok, app_handle} <- Session.get_app_handle(session),
         {:ok, field_result} <-
           Session.request(session, "GetField", app_handle, build_get_field_params(field_name), opts),
         {:ok, field_handle} <- Protocol.extract_handle(field_result),
         {:ok, _} <- Session.request(session, "SelectValues", field_handle, build_select_field_values(values), opts) do
      :ok
    end
  end

  @doc """
  Clears all selections in the app.

  ## Examples

      :ok = App.clear_selections(session)

  """
  @spec clear_selections(pid(), keyword()) :: :ok | {:error, Error.t()}
  def clear_selections(session, opts \\ []) do
    with {:ok, app_handle} <- Session.get_app_handle(session),
         {:ok, _} <- Session.request(session, "ClearAll", app_handle, [false], opts) do
      :ok
    end
  end

  @doc """
  Evaluates a Qlik expression.

  ## Examples

      {:ok, 1234567.89} = App.evaluate(session, "Sum(Sales)")
      {:ok, "Q1 2024"} = App.evaluate(session, "=Max(Quarter)")

  """
  @spec evaluate(pid(), String.t(), keyword()) :: {:ok, any()} | {:error, Error.t()}
  def evaluate(session, expression, opts \\ []) do
    with {:ok, app_handle} <- Session.get_app_handle(session),
         {:ok, result} <- Session.request(session, "Evaluate", app_handle, build_evaluate_params(expression), opts) do
      parse_evaluate_response(result)
    end
  end

  # Response parsers (also used in tests)

  @doc false
  @spec parse_sheets_response({:ok, map()} | {:error, any()}) :: {:ok, list()} | {:error, any()}
  def parse_sheets_response({:ok, result}), do: Protocol.extract_sheets(result)
  def parse_sheets_response({:error, _} = error), do: error

  @doc false
  @spec parse_objects_response({:ok, map()} | {:error, any()}) :: {:ok, list()} | {:error, any()}
  def parse_objects_response({:ok, %{"qLayout" => %{"qChildList" => %{"qItems" => items}}}}) when is_list(items) do
    {:ok, items}
  end

  def parse_objects_response({:ok, _}), do: {:ok, []}
  def parse_objects_response({:error, _} = error), do: error

  @doc false
  @spec parse_layout_response({:ok, map()} | {:error, any()}) :: {:ok, map()} | {:error, any()}
  def parse_layout_response({:ok, %{"qLayout" => layout}}), do: {:ok, layout}
  def parse_layout_response({:ok, result}), do: {:ok, result}
  def parse_layout_response({:error, _} = error), do: error

  @doc false
  @spec parse_hypercube_response({:ok, map()} | {:error, any()}) :: {:ok, list()} | {:error, any()}
  def parse_hypercube_response({:ok, result}), do: Protocol.extract_hypercube_data(result)
  def parse_hypercube_response({:error, _} = error), do: error

  @doc false
  @spec format_hypercube_data(list(), map()) :: hypercube_result()
  def format_hypercube_data(data, layout) do
    hypercube = layout["qHyperCube"] || %{}
    dimensions = hypercube["qDimensionInfo"] || []
    measures = hypercube["qMeasureInfo"] || []

    headers =
      Enum.map(dimensions, &(&1["qFallbackTitle"] || &1["qGroupFieldDefs"] |> List.first())) ++
        Enum.map(measures, &(&1["qFallbackTitle"] || "Measure"))

    rows =
      Enum.map(data, fn row ->
        %{
          text: Enum.map(row, &(&1["qText"] || to_string(&1["qNum"]))),
          values: Enum.map(row, &extract_value/1)
        }
      end)

    %{
      headers: headers,
      rows: rows,
      total_rows: length(data),
      truncated: false
    }
  end

  # Parameter builders

  @doc false
  def build_select_values_params(_field, values) do
    value_list = Enum.map(values, &%{"qText" => &1})
    ["/qListObjectDef", value_list, false, false]
  end

  @doc false
  def build_evaluate_params(expression) do
    %{"qExpression" => expression}
  end

  @doc false
  def build_get_field_params(field_name) do
    %{"qFieldName" => field_name}
  end

  # Private helpers

  defp fetch_all_hypercube_pages(session, object_handle, path, page_size, max_rows, opts) do
    fetch_pages(session, object_handle, path, page_size, max_rows, 0, [], opts)
  end

  defp fetch_pages(_session, _handle, _path, _page_size, max_rows, top, acc, _opts) when top >= max_rows do
    {:ok, acc |> Enum.reverse() |> Enum.concat()}
  end

  defp fetch_pages(session, handle, path, page_size, max_rows, top, acc, opts) do
    remaining = max_rows - top
    height = min(page_size, remaining)
    page = [%{qTop: top, qLeft: 0, qHeight: height, qWidth: 100}]
    params = Protocol.build_get_hypercube_data(path, page)

    case Session.request(session, "GetHyperCubeData", handle, params, opts) do
      {:ok, result} ->
        case parse_hypercube_response({:ok, result}) do
          {:ok, []} ->
            {:ok, acc |> Enum.reverse() |> Enum.concat()}

          {:ok, rows} ->
            if length(rows) < height do
              {:ok, [rows | acc] |> Enum.reverse() |> Enum.concat()}
            else
              fetch_pages(session, handle, path, page_size, max_rows, top + length(rows), [rows | acc], opts)
            end
        end

      {:error, _} = error ->
        error
    end
  end

  defp build_select_field_values(values) do
    value_list = Enum.map(values, &%{"qText" => &1})
    [value_list, false]
  end

  defp parse_evaluate_response(%{"qReturn" => value}), do: {:ok, value}
  defp parse_evaluate_response(%{"qValue" => value}) when is_number(value), do: {:ok, value}
  defp parse_evaluate_response(%{"qValue" => value}), do: {:ok, value}
  defp parse_evaluate_response(result) when is_binary(result), do: {:ok, result}
  defp parse_evaluate_response(result) when is_number(result), do: {:ok, result}
  defp parse_evaluate_response(_), do: {:ok, nil}

  defp extract_value(%{"qNum" => num}) when is_number(num), do: num
  defp extract_value(%{"qNum" => "NaN", "qText" => text}), do: text
  defp extract_value(%{"qText" => text}), do: text
  defp extract_value(cell), do: cell
end
