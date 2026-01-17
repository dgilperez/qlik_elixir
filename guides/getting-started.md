# Getting Started

This guide will help you get up and running with QlikElixir in minutes.

## Prerequisites

- Elixir 1.18 or later
- A Qlik Cloud account with API access
- An API key from Qlik Cloud

### Getting Your API Key

1. Log in to your [Qlik Cloud](https://www.qlik.com/us/products/qlik-cloud) tenant
2. Go to **Settings** > **API keys**
3. Click **Generate new key**
4. Copy the key (you won't be able to see it again)

## Installation

Add `qlik_elixir` to your `mix.exs`:

```elixir
def deps do
  [
    {:qlik_elixir, "~> 0.3.0"}
  ]
end
```

Then run:

```bash
mix deps.get
```

## Configuration

QlikElixir supports three configuration methods. Choose the one that fits your needs.

### Environment Variables (Recommended for Production)

Set these environment variables:

```bash
export QLIK_API_KEY="your-api-key"
export QLIK_TENANT_URL="https://your-tenant.region.qlikcloud.com"
export QLIK_CONNECTION_ID="optional-default-connection-id"
```

QlikElixir will automatically use these when no explicit config is provided.

### Application Config

Add to your `config/config.exs` or environment-specific config:

```elixir
config :qlik_elixir,
  api_key: System.get_env("QLIK_API_KEY"),
  tenant_url: System.get_env("QLIK_TENANT_URL"),
  connection_id: System.get_env("QLIK_CONNECTION_ID")
```

### Runtime Config

For dynamic configuration or multiple tenants:

```elixir
config = QlikElixir.new_config(
  api_key: "your-api-key",
  tenant_url: "https://your-tenant.region.qlikcloud.com"
)

# Pass to any function
{:ok, apps} = QlikElixir.REST.Apps.list(config: config)
```

## Your First API Calls

### List Your Apps

```elixir
# Using default config (from env vars or application config)
{:ok, %{"data" => apps}} = QlikElixir.REST.Apps.list()

# Display app names
Enum.each(apps, fn app ->
  IO.puts("- #{app["name"]} (#{app["id"]})")
end)
```

### Get App Details

```elixir
{:ok, app} = QlikElixir.REST.Apps.get("your-app-id")
IO.inspect(app, label: "App details")
```

### Upload a Data File

```elixir
# Upload a CSV file
{:ok, file} = QlikElixir.REST.DataFiles.upload_file("data/sales.csv")
IO.puts("Uploaded file ID: #{file["id"]}")
```

### Trigger a Reload

```elixir
# Start a reload
{:ok, reload} = QlikElixir.REST.Reloads.create("your-app-id")
IO.puts("Reload started: #{reload["id"]}")

# Check reload status
{:ok, status} = QlikElixir.REST.Reloads.get(reload["id"])
IO.puts("Status: #{status["status"]}")
```

## Extracting Data with QIX Engine

The QIX Engine lets you extract actual data from Qlik visualizations:

```elixir
alias QlikElixir.QIX.{Session, App}

# Create config for QIX connection
config = QlikElixir.new_config(
  api_key: "your-api-key",
  tenant_url: "https://your-tenant.region.qlikcloud.com"
)

# Connect to an app
{:ok, session} = Session.connect("your-app-id", config: config)

# List available sheets
{:ok, sheets} = App.list_sheets(session)
IO.puts("Found #{length(sheets)} sheets")

# Get objects on the first sheet
first_sheet = hd(sheets)
{:ok, objects} = App.list_objects(session, first_sheet["qInfo"]["qId"])

# Find a table or chart and extract its data
chart = Enum.find(objects, & &1["qInfo"]["qType"] == "barchart")

if chart do
  {:ok, data} = App.get_hypercube_data(session, chart["qInfo"]["qId"])

  IO.puts("Headers: #{inspect(data.headers)}")
  IO.puts("Rows: #{data.total_rows}")

  Enum.take(data.rows, 5)
  |> Enum.each(fn row ->
    IO.inspect(row.text)
  end)
end

# Always disconnect when done
Session.disconnect(session)
```

## Error Handling

QlikElixir uses tagged tuples and a custom `Error` struct:

```elixir
case QlikElixir.REST.Apps.get("non-existent-id") do
  {:ok, app} ->
    IO.puts("Found: #{app["name"]}")

  {:error, %QlikElixir.Error{type: :not_found}} ->
    IO.puts("App not found")

  {:error, %QlikElixir.Error{type: :authentication_error}} ->
    IO.puts("Check your API key")

  {:error, %QlikElixir.Error{message: msg}} ->
    IO.puts("Error: #{msg}")
end
```

### Common Error Types

| Error Type | Description |
|------------|-------------|
| `:authentication_error` | Invalid or missing API key |
| `:authorization_error` | Insufficient permissions |
| `:not_found` | Resource doesn't exist |
| `:validation_error` | Invalid parameters |
| `:file_exists_error` | File already exists (use `overwrite: true`) |
| `:file_too_large` | File exceeds 500MB limit |
| `:network_error` | Connection issues |

## Next Steps

- **[REST APIs Guide](rest-apis.md)** - Learn about all available REST API modules
- **[QIX Engine Guide](qix-engine.md)** - Deep dive into data extraction
- **[HexDocs](https://hexdocs.pm/qlik_elixir)** - Full API documentation

## Getting Help

- [GitHub Issues](https://github.com/dgilperez/qlik_elixir/issues) - Report bugs or request features
- [Qlik Developer Portal](https://qlik.dev/) - Official Qlik API documentation
- [Qlik Community](https://community.qlik.com/) - Community forums
