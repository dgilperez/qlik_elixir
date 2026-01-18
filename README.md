# QlikElixir

[![Hex.pm](https://img.shields.io/hexpm/v/qlik_elixir.svg)](https://hex.pm/packages/qlik_elixir)
[![Docs](https://img.shields.io/badge/hex-docs-blue.svg)](https://hexdocs.pm/qlik_elixir)
[![License](https://img.shields.io/hexpm/l/qlik_elixir.svg)](https://github.com/dgilperez/qlik_elixir/blob/master/LICENSE)

A comprehensive Elixir client for [Qlik Cloud](https://www.qlik.com/us/products/qlik-cloud) REST APIs and QIX Engine.

## Features

**REST APIs** - Full coverage of Qlik Cloud management APIs:
- **Apps** - Create, manage, publish, and export Qlik Sense applications
- **Spaces** - Manage shared and managed spaces with role assignments
- **Data Files** - Upload, manage, and organize data files
- **Reloads** - Trigger and monitor app data reloads
- **Users & Groups** - User management and access control
- **Automations** - Create and run no-code workflows
- **Webhooks** - Configure event notifications
- **And more** - API Keys, Data Connections, Items, Collections, Reports, Natural Language

**QIX Engine** - Real-time data extraction via WebSocket:
- Connect to apps and navigate sheets/objects
- **Extract hypercube data** from visualizations (the core value!)
- Make selections and filter data
- Evaluate custom expressions
- Stream large datasets efficiently

## Installation

Add `qlik_elixir` to your dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:qlik_elixir, "~> 0.3.3"}
  ]
end
```

## Quick Start

### Configuration

```elixir
# Option 1: Environment variables (recommended for production)
# QLIK_API_KEY=your-api-key
# QLIK_TENANT_URL=https://your-tenant.region.qlikcloud.com

# Option 2: Application config
config :qlik_elixir,
  api_key: "your-api-key",
  tenant_url: "https://your-tenant.region.qlikcloud.com"

# Option 3: Runtime config (for multiple tenants)
config = QlikElixir.new_config(
  api_key: "your-api-key",
  tenant_url: "https://your-tenant.region.qlikcloud.com"
)
```

### REST API Examples

```elixir
# List apps
{:ok, %{"data" => apps}} = QlikElixir.REST.Apps.list()

# Get app details
{:ok, app} = QlikElixir.REST.Apps.get("app-id")

# Trigger a reload
{:ok, reload} = QlikElixir.REST.Reloads.create("app-id")

# Upload a CSV file
{:ok, file} = QlikElixir.REST.DataFiles.upload_file("sales_data.csv")

# List spaces
{:ok, %{"data" => spaces}} = QlikElixir.REST.Spaces.list()
```

### QIX Engine - Data Extraction

```elixir
alias QlikElixir.QIX.{Session, App}

# Connect to an app
{:ok, session} = Session.connect("app-id", config: config)

# List sheets
{:ok, sheets} = App.list_sheets(session)

# Get visualization data (the main event!)
{:ok, data} = App.get_hypercube_data(session, "object-id")
# Returns:
# %{
#   headers: ["Country", "Sales", "Margin"],
#   rows: [
#     %{text: ["USA", "$1.2M", "23%"], values: ["USA", 1200000, 0.23]},
#     %{text: ["Germany", "$900K", "19%"], values: ["Germany", 900000, 0.19]}
#   ],
#   total_rows: 50,
#   truncated: false
# }

# Make selections
:ok = App.select_values(session, "Country", ["USA", "Germany"])

# Evaluate expressions
{:ok, total} = App.evaluate(session, "Sum(Sales)")

# Disconnect
:ok = Session.disconnect(session)
```

## API Reference

### REST APIs

| Module | Description | Qlik API Reference |
|--------|-------------|-------------------|
| [`QlikElixir.REST.Apps`](https://hexdocs.pm/qlik_elixir/QlikElixir.REST.Apps.html) | App management, publishing, export/import | [Apps API](https://qlik.dev/apis/rest/apps/) |
| [`QlikElixir.REST.Spaces`](https://hexdocs.pm/qlik_elixir/QlikElixir.REST.Spaces.html) | Spaces and role assignments | [Spaces API](https://qlik.dev/apis/rest/spaces/) |
| [`QlikElixir.REST.DataFiles`](https://hexdocs.pm/qlik_elixir/QlikElixir.REST.DataFiles.html) | File upload and management | [Data Files API](https://qlik.dev/apis/rest/data-files/) |
| [`QlikElixir.REST.Reloads`](https://hexdocs.pm/qlik_elixir/QlikElixir.REST.Reloads.html) | Trigger and monitor reloads | [Reloads API](https://qlik.dev/apis/rest/reloads/) |
| [`QlikElixir.REST.Users`](https://hexdocs.pm/qlik_elixir/QlikElixir.REST.Users.html) | User management | [Users API](https://qlik.dev/apis/rest/users/) |
| [`QlikElixir.REST.Groups`](https://hexdocs.pm/qlik_elixir/QlikElixir.REST.Groups.html) | Group management | [Groups API](https://qlik.dev/apis/rest/groups/) |
| [`QlikElixir.REST.APIKeys`](https://hexdocs.pm/qlik_elixir/QlikElixir.REST.APIKeys.html) | API key management | [API Keys API](https://qlik.dev/apis/rest/api-keys/) |
| [`QlikElixir.REST.Automations`](https://hexdocs.pm/qlik_elixir/QlikElixir.REST.Automations.html) | Automation workflows | [Automations API](https://qlik.dev/apis/rest/automations/) |
| [`QlikElixir.REST.Webhooks`](https://hexdocs.pm/qlik_elixir/QlikElixir.REST.Webhooks.html) | Event notifications | [Webhooks API](https://qlik.dev/apis/rest/webhooks/) |
| [`QlikElixir.REST.DataConnections`](https://hexdocs.pm/qlik_elixir/QlikElixir.REST.DataConnections.html) | External data sources | [Data Connections API](https://qlik.dev/apis/rest/data-connections/) |
| [`QlikElixir.REST.Items`](https://hexdocs.pm/qlik_elixir/QlikElixir.REST.Items.html) | Unified resource listing | [Items API](https://qlik.dev/apis/rest/items/) |
| [`QlikElixir.REST.Collections`](https://hexdocs.pm/qlik_elixir/QlikElixir.REST.Collections.html) | Content organization | [Collections API](https://qlik.dev/apis/rest/collections/) |
| [`QlikElixir.REST.Reports`](https://hexdocs.pm/qlik_elixir/QlikElixir.REST.Reports.html) | Report generation | [Reports API](https://qlik.dev/apis/rest/reports/) |
| [`QlikElixir.REST.Tenants`](https://hexdocs.pm/qlik_elixir/QlikElixir.REST.Tenants.html) | Tenant configuration | [Tenants API](https://qlik.dev/apis/rest/tenants/) |
| [`QlikElixir.REST.Roles`](https://hexdocs.pm/qlik_elixir/QlikElixir.REST.Roles.html) | Role definitions | [Roles API](https://qlik.dev/apis/rest/roles/) |
| [`QlikElixir.REST.Audits`](https://hexdocs.pm/qlik_elixir/QlikElixir.REST.Audits.html) | Audit logging | [Audits API](https://qlik.dev/apis/rest/audits/) |
| [`QlikElixir.REST.NaturalLanguage`](https://hexdocs.pm/qlik_elixir/QlikElixir.REST.NaturalLanguage.html) | Conversational analytics | [Insight Advisor API](https://qlik.dev/apis/rest/nl/) |

### QIX Engine (WebSocket)

| Module | Description | Qlik API Reference |
|--------|-------------|-------------------|
| [`QlikElixir.QIX.Session`](https://hexdocs.pm/qlik_elixir/QlikElixir.QIX.Session.html) | WebSocket connection management | [QIX Overview](https://qlik.dev/apis/json-rpc/qix/) |
| [`QlikElixir.QIX.App`](https://hexdocs.pm/qlik_elixir/QlikElixir.QIX.App.html) | High-level data extraction API | [Doc API](https://qlik.dev/apis/json-rpc/qix/doc/) |
| [`QlikElixir.QIX.Protocol`](https://hexdocs.pm/qlik_elixir/QlikElixir.QIX.Protocol.html) | JSON-RPC protocol handling | [GenericObject API](https://qlik.dev/apis/json-rpc/qix/genericobject/) |

### Core Modules

| Module | Description |
|--------|-------------|
| [`QlikElixir.Config`](https://hexdocs.pm/qlik_elixir/QlikElixir.Config.html) | Configuration management |
| [`QlikElixir.Error`](https://hexdocs.pm/qlik_elixir/QlikElixir.Error.html) | Error types and handling |
| [`QlikElixir.Pagination`](https://hexdocs.pm/qlik_elixir/QlikElixir.Pagination.html) | Cursor-based pagination helpers |

## API Testing Status

All 362 tests pass (100% coverage with Bypass HTTP mocking).

The following table shows **integration testing** status against real Qlik Cloud APIs:

| Module | Read | Write | Notes |
|--------|:----:|:-----:|-------|
| **Apps** | ✅ | ✅ | create, get, update, copy, delete, get_metadata, get_lineage, get_script, validate_script, list_media, get_thumbnail, export |
| **Spaces** | ✅ | ✅ | create, get, update, delete, list_types, list_assignments |
| **DataFiles** | ✅ | ✅ | list, get, upload, delete, find_by_name |
| **Reloads** | ✅ | ✅ | list, get, create, cancel |
| **Collections** | ✅ | ✅ | create, get, update, delete, list_items, add_item, remove_item, get_favorites |
| **Items** | ✅ | - | list, get, find_by_resource, get_published_items, get_collections |
| **Users** | ✅ | - | me, list, count |
| **Groups** | ✅ | - | list, list_settings |
| **Roles** | ✅ | - | list, get |
| **APIKeys** | ✅ | - | get_config requires tenant_id |
| **Automations** | ✅ | - | list, list_runs |
| **Webhooks** | ✅ | - | list, list_event_types |
| **DataConnections** | ✅ | - | list, get |
| **NaturalLanguage** | ✅ | - | get_model, list_analysis_types, ask, recommend |
| **Audits** | ✅ | - | list, get, list_sources, list_types |
| **Tenants** | ✅ | - | me |
| **Reports** | ⚠️ | - | API returns 404 (may require entitlement) |

### Untested Write Operations

The following write operations have unit tests but have not been integration tested:

| Module | Untested Operations | Reason |
|--------|---------------------|--------|
| Apps | publish, import_app | Requires published app setup |
| Spaces | create_assignment, delete_assignment | Requires user IDs |
| DataFiles | update, change_owner, change_space, batch_* | Requires specific setup |
| Items | update, delete | Affects catalog items |
| Users | create, update, delete, invite | Tenant admin operations |
| Groups | create, update, delete, update_settings | Group management |
| APIKeys | create, update, delete, update_config | Security sensitive |
| Automations | create, update, delete, run, enable, disable, etc. | Complex setup |
| Webhooks | create, update, delete, resend_delivery | Requires callback URL |
| DataConnections | create, update, delete | Requires datasourceID |
| Tenants | get, create, update, deactivate, reactivate | Tenant admin only |

**QIX Engine (WebSocket):** ✅ Fully integration tested - Session, App, data extraction

## Common Patterns

### Pagination

All list endpoints support cursor-based pagination:

```elixir
# First page
{:ok, %{"data" => apps, "links" => %{"next" => %{"href" => next_url}}}} =
  QlikElixir.REST.Apps.list(limit: 20)

# Get cursor from next URL and fetch next page
{:ok, page2} = QlikElixir.REST.Apps.list(limit: 20, next: cursor)

# Or use the Pagination helper
QlikElixir.Pagination.stream(fn cursor ->
  QlikElixir.REST.Apps.list(limit: 100, next: cursor)
end)
|> Enum.take(500)  # Get up to 500 apps
```

### Error Handling

```elixir
case QlikElixir.REST.Apps.get("app-id") do
  {:ok, app} ->
    IO.puts("Found app: #{app["name"]}")

  {:error, %QlikElixir.Error{type: :not_found}} ->
    IO.puts("App not found")

  {:error, %QlikElixir.Error{type: :authentication_error}} ->
    IO.puts("Invalid API key")

  {:error, %QlikElixir.Error{} = error} ->
    IO.puts("Error: #{error.message}")
end
```

### Multiple Tenants

```elixir
# Create configs for different tenants
us_config = QlikElixir.new_config(
  api_key: System.fetch_env!("US_QLIK_API_KEY"),
  tenant_url: "https://us-tenant.us.qlikcloud.com"
)

eu_config = QlikElixir.new_config(
  api_key: System.fetch_env!("EU_QLIK_API_KEY"),
  tenant_url: "https://eu-tenant.eu.qlikcloud.com"
)

# Use specific config per request
{:ok, us_apps} = QlikElixir.REST.Apps.list(config: us_config)
{:ok, eu_apps} = QlikElixir.REST.Apps.list(config: eu_config)
```

### Streaming Large Datasets

```elixir
alias QlikElixir.QIX.{Session, App}

{:ok, session} = Session.connect("app-id", config: config)

# Stream hypercube data in pages
App.stream_hypercube_data(session, "object-id", page_size: 1000)
|> Stream.flat_map(& &1)
|> Stream.each(fn row ->
  # Process each row
  IO.inspect(row)
end)
|> Stream.run()
```

## Configuration Options

```elixir
config = QlikElixir.new_config(
  # Required
  api_key: "your-api-key",
  tenant_url: "https://your-tenant.region.qlikcloud.com",

  # Optional
  connection_id: "default-connection-id",  # For data files
  http_options: [
    timeout: :timer.minutes(5),    # Request timeout
    retry: :transient,              # Retry strategy
    max_retries: 3,                 # Max retry attempts
    retry_delay: fn n -> n * 1000 end  # Backoff function
  ]
)
```

## Development

```bash
# Install dependencies
mix deps.get

# Run tests
mix test

# Run with coverage
mix test --cover

# Check code quality
mix format --check-formatted
mix credo --strict
mix dialyzer

# Generate docs
mix docs
```

## Roadmap / TODO

PRs welcome! Here are some areas that could use contribution:

- [ ] **Themes API** - Manage app themes
- [ ] **Extensions API** - Visualization extensions management
- [ ] **Brands API** - Tenant branding configuration
- [ ] **Reports API** - Currently returns 404, needs investigation
- [ ] **Integration tests** - More write operation coverage (see Untested Write Operations above)

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Write tests first (TDD encouraged)
4. Ensure all checks pass (`mix format && mix credo --strict && mix test`)
5. Commit your changes
6. Push to the branch
7. Open a Pull Request

## License

MIT License - see [LICENSE](LICENSE) for details.

## Links

- [HexDocs](https://hexdocs.pm/qlik_elixir)
- [Hex.pm](https://hex.pm/packages/qlik_elixir)
- [GitHub](https://github.com/dgilperez/qlik_elixir)
- [Qlik Developer Portal](https://qlik.dev/)

---

## Sponsored by

This project is proudly sponsored by **[Balneario - Clínica de Longevidad de Cofrentes](https://balneario.com)**, a world-class longevity clinic and thermal spa in Valencia, Spain. Their support makes open source development like this possible.

Thank you for investing in the developer community!
