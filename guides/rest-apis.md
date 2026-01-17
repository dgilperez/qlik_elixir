# REST APIs Guide

QlikElixir provides comprehensive coverage of Qlik Cloud REST APIs for managing your analytics infrastructure.

## Overview

All REST API modules follow a consistent pattern:

```elixir
# List resources with pagination
{:ok, %{"data" => items}} = Module.list(limit: 20, next: cursor)

# Get a single resource
{:ok, resource} = Module.get(id)

# Create a resource
{:ok, created} = Module.create(%{name: "New Resource"})

# Update a resource
{:ok, updated} = Module.update(id, %{name: "Updated Name"})

# Delete a resource
:ok = Module.delete(id)
```

## Apps API

[`QlikElixir.REST.Apps`](https://hexdocs.pm/qlik_elixir/QlikElixir.REST.Apps.html) | [Qlik API Reference](https://qlik.dev/apis/rest/apps/)

Manage Qlik Sense applications - the core analytics containers.

```elixir
alias QlikElixir.REST.Apps

# List apps
{:ok, %{"data" => apps}} = Apps.list(limit: 50, space_id: "space-123")

# Get app details
{:ok, app} = Apps.get("app-id")

# Create an app
{:ok, app} = Apps.create(%{name: "Sales Dashboard", space_id: "space-123"})

# Copy an app
{:ok, copy} = Apps.copy("app-id", name: "Dashboard Copy", space_id: "space-456")

# Publish to a managed space
{:ok, published} = Apps.publish("app-id", "managed-space-id")

# Export as .qvf binary
{:ok, binary} = Apps.export("app-id")
File.write!("app-backup.qvf", binary)

# Import from .qvf
binary = File.read!("app.qvf")
{:ok, imported} = Apps.import_app(binary, name: "Imported App")

# Get/validate load script
{:ok, %{"script" => script}} = Apps.get_script("app-id")
{:ok, validation} = Apps.validate_script(script)

# App metadata
{:ok, metadata} = Apps.get_metadata("app-id")
{:ok, lineage} = Apps.get_lineage("app-id")

# Media files
{:ok, media} = Apps.list_media("app-id")
{:ok, thumbnail} = Apps.get_thumbnail("app-id")
```

## Spaces API

[`QlikElixir.REST.Spaces`](https://hexdocs.pm/qlik_elixir/QlikElixir.REST.Spaces.html) | [Qlik API Reference](https://qlik.dev/apis/rest/spaces/)

Manage shared and managed spaces for organizing content and controlling access.

```elixir
alias QlikElixir.REST.Spaces

# List spaces
{:ok, %{"data" => spaces}} = Spaces.list(type: "shared")

# Create a shared space
{:ok, space} = Spaces.create(%{name: "Team Analytics", type: "shared"})

# Get space details
{:ok, space} = Spaces.get("space-id")

# Update space
{:ok, updated} = Spaces.update("space-id", %{name: "Updated Name"})

# Manage role assignments
{:ok, assignments} = Spaces.list_assignments("space-id")

{:ok, assignment} = Spaces.create_assignment("space-id", %{
  type: "user",
  assignee_id: "user-id",
  roles: ["consumer", "contributor"]
})

:ok = Spaces.delete_assignment("space-id", "assignment-id")

# List available space types
{:ok, types} = Spaces.list_types()
```

## Data Files API

[`QlikElixir.REST.DataFiles`](https://hexdocs.pm/qlik_elixir/QlikElixir.REST.DataFiles.html) | [Qlik API Reference](https://qlik.dev/apis/rest/data-files/)

Upload and manage data files used by apps.

```elixir
alias QlikElixir.REST.DataFiles

# List files
{:ok, %{"data" => files}} = DataFiles.list(connection_id: "conn-123")

# Upload from file path
{:ok, file} = DataFiles.upload_file("sales.csv", overwrite: true)

# Upload binary content
csv = "id,name\n1,Alice\n2,Bob"
{:ok, file} = DataFiles.upload_content(csv, "users.csv")

# Get file details
{:ok, file} = DataFiles.get("file-id")

# Check if file exists
true = DataFiles.file_exists?("sales.csv")

# Find by name
{:ok, file} = DataFiles.find_file_by_name("sales.csv")

# Move to another space
{:ok, _} = DataFiles.change_space("file-id", "new-space-id")

# Batch operations
:ok = DataFiles.batch_delete(["file-1", "file-2", "file-3"])
:ok = DataFiles.batch_change_space(["file-1", "file-2"], "space-id")

# Check quotas
{:ok, quotas} = DataFiles.get_quotas()
```

## Reloads API

[`QlikElixir.REST.Reloads`](https://hexdocs.pm/qlik_elixir/QlikElixir.REST.Reloads.html) | [Qlik API Reference](https://qlik.dev/apis/rest/reloads/)

Trigger and monitor app data reloads.

```elixir
alias QlikElixir.REST.Reloads

# List recent reloads
{:ok, %{"data" => reloads}} = Reloads.list(app_id: "app-123")

# Trigger a reload
{:ok, reload} = Reloads.create("app-id", partial: false)

# Check status
{:ok, reload} = Reloads.get(reload["id"])
IO.puts("Status: #{reload["status"]}")  # QUEUED, RELOADING, SUCCEEDED, FAILED

# Cancel a running reload
:ok = Reloads.cancel(reload["id"])

# Poll until complete
defmodule ReloadHelper do
  def wait_for_reload(reload_id, timeout \\ 300_000) do
    start = System.monotonic_time(:millisecond)

    Stream.repeatedly(fn ->
      Process.sleep(5000)
      Reloads.get(reload_id)
    end)
    |> Stream.take_while(fn
      {:ok, %{"status" => status}} when status in ["QUEUED", "RELOADING"] ->
        System.monotonic_time(:millisecond) - start < timeout
      _ ->
        false
    end)
    |> Enum.to_list()
    |> List.last()
  end
end
```

## Users API

[`QlikElixir.REST.Users`](https://hexdocs.pm/qlik_elixir/QlikElixir.REST.Users.html) | [Qlik API Reference](https://qlik.dev/apis/rest/users/)

Manage users in your Qlik Cloud tenant.

```elixir
alias QlikElixir.REST.Users

# List users
{:ok, %{"data" => users}} = Users.list(limit: 100)

# Get current user
{:ok, me} = Users.me()

# Get user count
{:ok, %{"total" => count}} = Users.count()

# Get user by ID
{:ok, user} = Users.get("user-id")

# Filter users
{:ok, %{"data" => filtered}} = Users.filter("email eq 'user@example.com'")

# Invite users
{:ok, result} = Users.invite(["new@example.com", "another@example.com"])

# Create user
{:ok, user} = Users.create(%{
  name: "John Doe",
  email: "john@example.com",
  subject: "auth0|123456"
})
```

## Automations API

[`QlikElixir.REST.Automations`](https://hexdocs.pm/qlik_elixir/QlikElixir.REST.Automations.html) | [Qlik API Reference](https://qlik.dev/apis/rest/automations/)

Create and manage no-code automation workflows.

```elixir
alias QlikElixir.REST.Automations

# List automations
{:ok, %{"data" => autos}} = Automations.list(state: "enabled")

# Get automation details
{:ok, auto} = Automations.get("automation-id")

# Enable/disable
{:ok, _} = Automations.enable("automation-id")
{:ok, _} = Automations.disable("automation-id")

# Trigger a run
{:ok, run} = Automations.run("automation-id", inputs: %{"param1" => "value1"})

# List runs
{:ok, %{"data" => runs}} = Automations.list_runs("automation-id")

# Get run details
{:ok, run} = Automations.get_run("automation-id", "run-id")

# Stop or retry
:ok = Automations.stop_run("automation-id", "run-id")
{:ok, _} = Automations.retry_run("automation-id", "run-id")

# Usage statistics
{:ok, usage} = Automations.get_usage()
```

## Webhooks API

[`QlikElixir.REST.Webhooks`](https://hexdocs.pm/qlik_elixir/QlikElixir.REST.Webhooks.html) | [Qlik API Reference](https://qlik.dev/apis/rest/webhooks/)

Configure event notifications.

```elixir
alias QlikElixir.REST.Webhooks

# List webhooks
{:ok, %{"data" => hooks}} = Webhooks.list()

# Available event types
{:ok, types} = Webhooks.list_event_types()

# Create webhook
{:ok, hook} = Webhooks.create(%{
  name: "Reload Notifications",
  url: "https://api.example.com/webhooks/qlik",
  eventTypes: ["com.qlik.v1.reload.finished"],
  enabled: true
})

# Update webhook
{:ok, _} = Webhooks.update("webhook-id", %{enabled: false})

# View deliveries
{:ok, %{"data" => deliveries}} = Webhooks.list_deliveries("webhook-id")
{:ok, delivery} = Webhooks.get_delivery("webhook-id", "delivery-id")

# Retry failed delivery
{:ok, _} = Webhooks.resend_delivery("webhook-id", "delivery-id")
```

## Data Connections API

[`QlikElixir.REST.DataConnections`](https://hexdocs.pm/qlik_elixir/QlikElixir.REST.DataConnections.html) | [Qlik API Reference](https://qlik.dev/apis/rest/data-connections/)

Manage external data source connections.

```elixir
alias QlikElixir.REST.DataConnections

# List connections
{:ok, %{"data" => conns}} = DataConnections.list(space_id: "space-123")

# Create connection
{:ok, conn} = DataConnections.create(%{
  name: "Sales Database",
  type: "PostgreSQL",
  connectionString: "host=db.example.com;port=5432;database=sales"
})

# Duplicate connection
{:ok, copy} = DataConnections.duplicate("conn-id", name: "Sales DB Copy")

# Batch operations
:ok = DataConnections.batch_delete(["conn-1", "conn-2"])
{:ok, _} = DataConnections.batch_update([
  %{id: "conn-1", name: "Updated Name 1"},
  %{id: "conn-2", name: "Updated Name 2"}
])
```

## Items API

[`QlikElixir.REST.Items`](https://hexdocs.pm/qlik_elixir/QlikElixir.REST.Items.html) | [Qlik API Reference](https://qlik.dev/apis/rest/items/)

Unified view of all content items (apps, data files, etc.).

```elixir
alias QlikElixir.REST.Items

# List all items
{:ok, %{"data" => items}} = Items.list(resource_type: "app")

# Get item details
{:ok, item} = Items.get("item-id")

# Update item metadata
{:ok, _} = Items.update("item-id", %{name: "New Name"})
```

## Collections API

[`QlikElixir.REST.Collections`](https://hexdocs.pm/qlik_elixir/QlikElixir.REST.Collections.html) | [Qlik API Reference](https://qlik.dev/apis/rest/collections/)

Organize content with collections.

```elixir
alias QlikElixir.REST.Collections

# List collections
{:ok, %{"data" => colls}} = Collections.list()

# Create collection
{:ok, coll} = Collections.create(%{name: "Q4 Reports", type: "private"})

# Manage items
{:ok, items} = Collections.list_items("collection-id")
{:ok, _} = Collections.add_items("collection-id", ["item-1", "item-2"])
:ok = Collections.remove_item("collection-id", "item-1")

# Get user's favorites
{:ok, %{"data" => favorites}} = Collections.get_favorites()
```

## Reports API

[`QlikElixir.REST.Reports`](https://hexdocs.pm/qlik_elixir/QlikElixir.REST.Reports.html) | [Qlik API Reference](https://qlik.dev/apis/rest/reports/)

Generate and download reports.

```elixir
alias QlikElixir.REST.Reports

# List reports
{:ok, %{"data" => reports}} = Reports.list()

# Create report
{:ok, report} = Reports.create(%{
  name: "Monthly Sales",
  app_id: "app-123",
  template_id: "template-456"
})

# Download report
{:ok, binary} = Reports.download("report-id")
File.write!("report.pdf", binary)
```

## Natural Language API

[`QlikElixir.REST.NaturalLanguage`](https://hexdocs.pm/qlik_elixir/QlikElixir.REST.NaturalLanguage.html) | [Qlik API Reference](https://qlik.dev/apis/rest/nl/)

Conversational analytics with Insight Advisor.

```elixir
alias QlikElixir.REST.NaturalLanguage

# Ask a natural language question
{:ok, result} = NaturalLanguage.ask("app-id", "What were total sales last quarter?")

# Get recommendations
{:ok, recommendations} = NaturalLanguage.get_recommendations("app-id")
```

## Pagination

All list endpoints support cursor-based pagination:

```elixir
# Manual pagination
{:ok, page1} = QlikElixir.REST.Apps.list(limit: 50)
cursor = page1["links"]["next"]["href"] |> extract_cursor()
{:ok, page2} = QlikElixir.REST.Apps.list(limit: 50, next: cursor)

# Stream all items
QlikElixir.Pagination.stream(fn cursor ->
  QlikElixir.REST.Apps.list(limit: 100, next: cursor)
end)
|> Enum.each(&process_app/1)
```

## Additional APIs

| Module | Description |
|--------|-------------|
| [`QlikElixir.REST.Groups`](https://hexdocs.pm/qlik_elixir/QlikElixir.REST.Groups.html) | User group management |
| [`QlikElixir.REST.APIKeys`](https://hexdocs.pm/qlik_elixir/QlikElixir.REST.APIKeys.html) | API key management |
| [`QlikElixir.REST.Tenants`](https://hexdocs.pm/qlik_elixir/QlikElixir.REST.Tenants.html) | Tenant configuration |
| [`QlikElixir.REST.Roles`](https://hexdocs.pm/qlik_elixir/QlikElixir.REST.Roles.html) | Role definitions |
| [`QlikElixir.REST.Audits`](https://hexdocs.pm/qlik_elixir/QlikElixir.REST.Audits.html) | Audit event logging |

## Next Steps

- **[QIX Engine Guide](qix-engine.md)** - Extract data from visualizations
- **[Getting Started](getting-started.md)** - Quick setup guide
