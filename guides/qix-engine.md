# QIX Engine Guide

The QIX Engine is Qlik's real-time analytics engine. While REST APIs manage resources, the QIX Engine lets you **extract actual data** from visualizations via WebSocket.

## Overview

The QIX Engine uses JSON-RPC 2.0 over WebSocket. QlikElixir provides a high-level API that handles:

- WebSocket connection management
- JSON-RPC protocol handling
- Object handle tracking
- Automatic pagination for large datasets

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Your Application                      │
├─────────────────────────────────────────────────────────┤
│  QlikElixir.QIX.App        (High-level API)             │
│    - list_sheets, list_objects                          │
│    - get_hypercube_data, stream_hypercube_data          │
│    - select_values, evaluate                            │
├─────────────────────────────────────────────────────────┤
│  QlikElixir.QIX.Session    (Connection Management)      │
│    - WebSocket via gun                                  │
│    - GenServer for state                                │
├─────────────────────────────────────────────────────────┤
│  QlikElixir.QIX.Protocol   (JSON-RPC Handling)          │
│    - Request/response encoding                          │
│    - Result extraction                                  │
└─────────────────────────────────────────────────────────┘
                          │
                          ▼
              Qlik Cloud QIX Engine (WebSocket)
```

## Connecting to an App

```elixir
alias QlikElixir.QIX.{Session, App}

# Create configuration
config = QlikElixir.new_config(
  api_key: System.fetch_env!("QLIK_API_KEY"),
  tenant_url: System.fetch_env!("QLIK_TENANT_URL")
)

# Connect to an app
{:ok, session} = Session.connect("your-app-id", config: config)

# The session is a GenServer pid
# Always disconnect when done
Session.disconnect(session)
```

### Connection Options

```elixir
{:ok, session} = Session.connect("app-id",
  config: config,
  timeout: 30_000,           # Connection timeout (ms)
  reconnect: true,           # Auto-reconnect on disconnect
  reconnect_delay: 5_000     # Delay between reconnect attempts
)
```

## Navigating the App

### List Sheets

```elixir
{:ok, sheets} = App.list_sheets(session)

Enum.each(sheets, fn sheet ->
  id = sheet["qInfo"]["qId"]
  title = sheet["qMeta"]["title"]
  IO.puts("Sheet: #{title} (#{id})")
end)
```

### List Objects on a Sheet

```elixir
# Get objects (charts, tables, filters) on a sheet
{:ok, objects} = App.list_objects(session, "sheet-id")

Enum.each(objects, fn obj ->
  id = obj["qInfo"]["qId"]
  type = obj["qInfo"]["qType"]  # barchart, linechart, table, etc.
  IO.puts("  #{type}: #{id}")
end)
```

### Get Object Layout

```elixir
# Get the full layout of an object (including hypercube definition)
{:ok, handle} = App.get_object(session, "object-id")
{:ok, layout} = App.get_layout(session, handle)

# Layout contains:
# - qInfo: object metadata
# - qHyperCube: data structure definition
#   - qDimensionInfo: dimension metadata
#   - qMeasureInfo: measure metadata
```

## Extracting Data

### Get Hypercube Data

This is the core function for extracting data from visualizations:

```elixir
{:ok, data} = App.get_hypercube_data(session, "object-id")

# Returns a structured result:
# %{
#   headers: ["Country", "Sales", "Margin %"],
#   rows: [
#     %{
#       text: ["USA", "$1,234,567", "23.5%"],
#       values: ["USA", 1234567, 0.235]
#     },
#     %{
#       text: ["Germany", "$987,654", "19.2%"],
#       values: ["Germany", 987654, 0.192]
#     }
#   ],
#   total_rows: 50,
#   truncated: false
# }

# Access headers
IO.puts("Columns: #{Enum.join(data.headers, ", ")}")

# Iterate rows
Enum.each(data.rows, fn row ->
  # text: formatted display values
  # values: raw numeric/string values
  IO.inspect(row.values)
end)
```

### Options

```elixir
{:ok, data} = App.get_hypercube_data(session, "object-id",
  page_size: 500,           # Rows per page (default: 1000)
  max_rows: 5000,           # Maximum rows to fetch (default: 10000)
  path: "/qHyperCubeDef",   # HyperCube path in layout
  format: :formatted        # :formatted (default) or :raw
)

# Raw format returns the matrix as-is from Qlik
{:ok, raw_data} = App.get_hypercube_data(session, "object-id", format: :raw)
# Returns: [[%{"qText" => "USA", "qNum" => ...}, ...], ...]
```

### Streaming Large Datasets

For datasets larger than memory, use streaming:

```elixir
# Returns a Stream that yields pages of rows
App.stream_hypercube_data(session, "object-id", page_size: 1000)
|> Stream.flat_map(& &1)          # Flatten pages into rows
|> Stream.with_index()
|> Stream.each(fn {row, idx} ->
  # Process each row
  if rem(idx, 10000) == 0 do
    IO.puts("Processed #{idx} rows...")
  end
end)
|> Stream.run()

# Write to CSV
File.open!("export.csv", [:write, :utf8], fn file ->
  App.stream_hypercube_data(session, "object-id")
  |> Stream.flat_map(& &1)
  |> Stream.each(fn row ->
    line = Enum.join(row, ",") <> "\n"
    IO.write(file, line)
  end)
  |> Stream.run()
end)
```

## Making Selections

Selections filter data across the entire app:

```elixir
# Select specific values in a field
:ok = App.select_values(session, "Country", ["USA", "Germany"])

# Now all data queries will be filtered
{:ok, filtered_data} = App.get_hypercube_data(session, "object-id")
# Returns only USA and Germany data

# Clear all selections
:ok = App.clear_selections(session)
```

### Selection Flow

```elixir
# 1. Get initial data
{:ok, all_data} = App.get_hypercube_data(session, "sales-chart")
IO.puts("Total rows: #{all_data.total_rows}")

# 2. Apply selection
:ok = App.select_values(session, "Region", ["EMEA"])

# 3. Get filtered data
{:ok, emea_data} = App.get_hypercube_data(session, "sales-chart")
IO.puts("EMEA rows: #{emea_data.total_rows}")

# 4. Add another selection (AND logic)
:ok = App.select_values(session, "Year", ["2024"])

# 5. Get doubly filtered data
{:ok, emea_2024} = App.get_hypercube_data(session, "sales-chart")
IO.puts("EMEA 2024 rows: #{emea_2024.total_rows}")

# 6. Clear and start fresh
:ok = App.clear_selections(session)
```

## Evaluating Expressions

Calculate custom Qlik expressions:

```elixir
# Simple aggregation
{:ok, total_sales} = App.evaluate(session, "Sum(Sales)")
IO.puts("Total Sales: #{total_sales}")

# With formatting
{:ok, formatted} = App.evaluate(session, "=Money(Sum(Sales), '$ #,##0')")

# Complex expressions
{:ok, margin} = App.evaluate(session, "Sum(Profit) / Sum(Revenue)")

# Set analysis
{:ok, ly_sales} = App.evaluate(session, "Sum({<Year={2023}>} Sales)")
{:ok, yoy_growth} = App.evaluate(session,
  "(Sum(Sales) - Sum({<Year={2023}>} Sales)) / Sum({<Year={2023}>} Sales)"
)
```

## Complete Example

Here's a full workflow for extracting sales data:

```elixir
defmodule SalesExport do
  alias QlikElixir.QIX.{Session, App}

  def export_regional_sales(app_id, regions, output_path) do
    config = QlikElixir.new_config(
      api_key: System.fetch_env!("QLIK_API_KEY"),
      tenant_url: System.fetch_env!("QLIK_TENANT_URL")
    )

    {:ok, session} = Session.connect(app_id, config: config)

    try do
      # Find the sales table
      {:ok, sheets} = App.list_sheets(session)
      sales_sheet = Enum.find(sheets, & &1["qMeta"]["title"] == "Sales Overview")

      {:ok, objects} = App.list_objects(session, sales_sheet["qInfo"]["qId"])
      sales_table = Enum.find(objects, & &1["qInfo"]["qType"] == "table")

      # Apply regional filter
      :ok = App.select_values(session, "Region", regions)

      # Extract data
      {:ok, data} = App.get_hypercube_data(session, sales_table["qInfo"]["qId"],
        max_rows: 100_000
      )

      # Write to CSV
      File.open!(output_path, [:write, :utf8], fn file ->
        # Header
        IO.write(file, Enum.join(data.headers, ",") <> "\n")

        # Rows
        Enum.each(data.rows, fn row ->
          line = row.text
            |> Enum.map(&escape_csv/1)
            |> Enum.join(",")
          IO.write(file, line <> "\n")
        end)
      end)

      IO.puts("Exported #{data.total_rows} rows to #{output_path}")

      # Get summary stats
      {:ok, total} = App.evaluate(session, "Sum(Sales)")
      {:ok, avg} = App.evaluate(session, "Avg(Sales)")
      IO.puts("Total: #{total}, Avg: #{avg}")

      :ok
    after
      Session.disconnect(session)
    end
  end

  defp escape_csv(value) when is_binary(value) do
    if String.contains?(value, [",", "\"", "\n"]) do
      "\"" <> String.replace(value, "\"", "\"\"") <> "\""
    else
      value
    end
  end
  defp escape_csv(value), do: to_string(value)
end

# Usage
SalesExport.export_regional_sales(
  "abc-123-def",
  ["EMEA", "APAC"],
  "regional_sales.csv"
)
```

## Error Handling

```elixir
case Session.connect(app_id, config: config) do
  {:ok, session} ->
    # Connected successfully
    do_work(session)
    Session.disconnect(session)

  {:error, %QlikElixir.Error{type: :authentication_error}} ->
    IO.puts("Check your API key")

  {:error, %QlikElixir.Error{type: :not_found}} ->
    IO.puts("App not found")

  {:error, %QlikElixir.Error{message: msg}} ->
    IO.puts("Connection failed: #{msg}")
end
```

## Best Practices

### 1. Always Disconnect

Use `try/after` to ensure cleanup:

```elixir
{:ok, session} = Session.connect(app_id, config: config)
try do
  # Your code
after
  Session.disconnect(session)
end
```

### 2. Limit Data Extraction

Don't extract more data than needed:

```elixir
# Good: Specify reasonable limits
{:ok, data} = App.get_hypercube_data(session, obj_id,
  max_rows: 10_000,
  page_size: 1000
)

# Bad: Extracting entire large datasets without limits
```

### 3. Use Streaming for Large Datasets

```elixir
# For datasets > 100k rows, use streaming
App.stream_hypercube_data(session, obj_id)
|> Stream.flat_map(& &1)
|> Stream.each(&process_row/1)
|> Stream.run()
```

### 4. Make Targeted Selections

Apply selections before extracting data to reduce volume:

```elixir
# Apply filters first
:ok = App.select_values(session, "Year", ["2024"])
:ok = App.select_values(session, "Region", ["EMEA"])

# Then extract (less data to transfer)
{:ok, data} = App.get_hypercube_data(session, obj_id)
```

## QIX API Reference

For advanced use cases, refer to the Qlik QIX API documentation:

- [QIX Overview](https://qlik.dev/apis/json-rpc/qix/)
- [Doc (App) Methods](https://qlik.dev/apis/json-rpc/qix/doc/)
- [GenericObject Methods](https://qlik.dev/apis/json-rpc/qix/genericobject/)
- [Field Methods](https://qlik.dev/apis/json-rpc/qix/field/)

## Next Steps

- **[REST APIs Guide](rest-apis.md)** - Manage apps, spaces, and more
- **[Getting Started](getting-started.md)** - Quick setup guide
