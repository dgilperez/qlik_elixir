# Product Requirements Document: QlikElixir Full API Coverage

## Executive Summary

Expand QlikElixir from a Data Files-only client to a comprehensive Elixir wrapper for the entire Qlik Cloud REST API suite, culminating in an MCP (Model Context Protocol) server that enables AI assistants to interact with Qlik Cloud.

## Vision

**Goal**: Become the definitive Elixir client for Qlik Cloud, enabling Elixir developers and AI systems to programmatically manage analytics infrastructure, data, and automations.

**End State**: An MCP server that allows Claude and other AI assistants to:
- Manage Qlik apps, spaces, and data files (REST APIs)
- **Extract and analyze data from visualizations** (QIX Engine)
- Trigger and monitor reloads
- Configure automations and webhooks

**Two Protocol Stack**:
- **REST APIs** - CRUD operations for management (apps, spaces, files, users)
- **QIX Engine** - WebSocket JSON-RPC for real-time data (hypercubes, selections, calculations)

## Current State (v0.2.x)

### Implemented
- Data Files API (partial): upload, list, delete, find

### Architecture
- `QlikElixir` - Public facade
- `QlikElixir.Client` - HTTP client
- `QlikElixir.Config` - Configuration
- `QlikElixir.Error` - Error handling
- `QlikElixir.Uploader` - File uploads

---

## Qlik Cloud API Inventory

### QIX Engine (WebSocket JSON-RPC) - P0

The QIX Engine is **the core value** - it's how you extract actual data from Qlik visualizations.

| Operation | Description |
|-----------|-------------|
| **Connect** | Open WebSocket session to app |
| **Get Sheets** | List all sheets in an app |
| **Get Objects** | List visualization objects on a sheet |
| **Get HyperCube Data** | Extract rows from a visualization (dimensions + measures) |
| **Make Selections** | Filter data by selecting values |
| **Evaluate Expression** | Calculate custom expressions |

Reference: https://qlik.dev/apis/json-rpc/qix/

### Tier 1: Core REST APIs (High Priority)

| API | Endpoints | Description | Priority |
|-----|-----------|-------------|----------|
| **Apps** | 47 | Core analytics applications | P0 |
| **Spaces** | 17 | Access control containers | P0 |
| **Data Files** | 12 | File storage (current) | P0 |
| **Reloads** | 4 | App data refresh | P0 |
| **Data Connections** | 9 | External data sources | P1 |
| **Users** | 9 | User management | P1 |
| **API Keys** | 7 | Programmatic access | P1 |

### Tier 2: Automation & Integration APIs

| API | Endpoints | Description | Priority |
|-----|-----------|-------------|----------|
| **Automations** | 18 | No-code workflows | P1 |
| **Webhooks** | 10 | Event notifications | P1 |
| **Reload Tasks** | TBD | Scheduled reloads | P2 |
| **Tasks** | TBD | Task management | P2 |

### Tier 3: Governance & Admin APIs

| API | Endpoints | Description | Priority |
|-----|-----------|-------------|----------|
| **Tenants** | 6 | Tenant configuration | P2 |
| **Audits** | TBD | Event logging | P2 |
| **Groups** | TBD | Access groups | P2 |
| **Roles** | TBD | Permission roles | P2 |
| **Licenses** | TBD | Entitlements | P3 |
| **Quotas** | TBD | Resource limits | P3 |

### Tier 4: Content & Analytics APIs

| API | Endpoints | Description | Priority |
|-----|-----------|-------------|----------|
| **Items** | TBD | Unified resource list | P2 |
| **Collections** | TBD | Content tagging | P2 |
| **Reports** | TBD | Downloadable assets | P2 |
| **Themes** | TBD | UI customization | P3 |
| **Extensions** | TBD | Visualizations | P3 |

### Tier 5: AI & Advanced APIs

| API | Endpoints | Description | Priority |
|-----|-----------|-------------|----------|
| **Natural Language** | TBD | Conversational analytics | P2 |
| **Machine Learning** | TBD | ML models | P3 |
| **Assistants** | TBD | Qlik Answers chat | P3 |
| **Lineage Graphs** | TBD | Data relationships | P3 |

---

## Phase 1: Foundation & Core APIs

### 1.1 Architecture Refactoring

**Objective**: Restructure codebase to support multiple API modules cleanly.

**Changes**:
```
lib/
├── qlik_elixir.ex                    # Facade (delegates)
├── qlik_elixir/
│   ├── client.ex                     # HTTP client (REST)
│   ├── config.ex                     # Configuration
│   ├── error.ex                      # Error types
│   ├── pagination.ex                 # Cursor-based pagination
│   │
│   ├── rest/                         # REST API modules
│   │   ├── apps.ex
│   │   ├── spaces.ex
│   │   ├── data_files.ex
│   │   ├── reloads.ex
│   │   └── ...
│   │
│   └── qix/                          # QIX Engine (WebSocket)
│       ├── session.ex                # Connection management
│       ├── app.ex                    # Sheets, objects
│       ├── hypercube.ex              # Data extraction
│       └── protocol.ex               # JSON-RPC handling
```

**Deliverables**:
- [ ] Create `QlikElixir.Pagination` module for cursor handling
- [ ] Create `QlikElixir.REST` namespace for REST APIs
- [ ] Create `QlikElixir.QIX` namespace for WebSocket/data extraction
- [ ] Refactor `Uploader` -> `REST.DataFiles`
- [ ] Expand `Error` types for all API scenarios
- [ ] Add response parsing helpers

### 1.2 Apps API

**Objective**: Full Apps API coverage.

**Endpoints**:
```elixir
QlikElixir.Apps.list(opts)                    # GET /apps
QlikElixir.Apps.create(params, opts)          # POST /apps
QlikElixir.Apps.get(app_id, opts)             # GET /apps/{id}
QlikElixir.Apps.update(app_id, params, opts)  # PUT /apps/{id}
QlikElixir.Apps.delete(app_id, opts)          # DELETE /apps/{id}
QlikElixir.Apps.copy(app_id, opts)            # POST /apps/{id}/copy
QlikElixir.Apps.publish(app_id, space_id, opts)  # POST /apps/{id}/publish
QlikElixir.Apps.export(app_id, opts)          # POST /apps/{id}/export
QlikElixir.Apps.import(binary, opts)          # POST /apps/import

# Metadata
QlikElixir.Apps.get_lineage(app_id, opts)     # GET /apps/{id}/data/lineage
QlikElixir.Apps.get_metadata(app_id, opts)    # GET /apps/{id}/data/metadata

# Scripts
QlikElixir.Apps.get_script(app_id, opts)      # GET /apps/{id}/scripts
QlikElixir.Apps.validate_script(script, opts) # POST /apps/validatescript

# Media
QlikElixir.Apps.list_media(app_id, path, opts)   # GET /apps/{id}/media/list/{path}
QlikElixir.Apps.get_thumbnail(app_id, opts)      # GET /apps/{id}/media/thumbnail
```

### 1.3 Spaces API

**Objective**: Full Spaces API coverage.

**Endpoints**:
```elixir
QlikElixir.Spaces.list(opts)                  # GET /spaces
QlikElixir.Spaces.create(params, opts)        # POST /spaces
QlikElixir.Spaces.get(space_id, opts)         # GET /spaces/{id}
QlikElixir.Spaces.update(space_id, params, opts)  # PATCH /spaces/{id}
QlikElixir.Spaces.delete(space_id, opts)      # DELETE /spaces/{id}

# Assignments
QlikElixir.Spaces.list_assignments(space_id, opts)
QlikElixir.Spaces.create_assignment(space_id, params, opts)
QlikElixir.Spaces.delete_assignment(space_id, assignment_id, opts)

# Space types
QlikElixir.Spaces.list_types(opts)            # GET /spaces/types
```

### 1.4 Reloads API

**Objective**: Full Reloads API coverage.

**Endpoints**:
```elixir
QlikElixir.Reloads.list(opts)                 # GET /reloads
QlikElixir.Reloads.create(app_id, opts)       # POST /reloads
QlikElixir.Reloads.get(reload_id, opts)       # GET /reloads/{id}
QlikElixir.Reloads.cancel(reload_id, opts)    # POST /reloads/{id}/actions/cancel
```

### 1.5 Data Files API (Complete)

**Objective**: Complete remaining Data Files endpoints.

**New Endpoints**:
```elixir
QlikElixir.DataFiles.get(file_id, opts)           # GET /data-files/{id}
QlikElixir.DataFiles.update(file_id, content, opts)  # PUT /data-files/{id}
QlikElixir.DataFiles.change_owner(file_id, owner_id, opts)
QlikElixir.DataFiles.change_space(file_id, space_id, opts)
QlikElixir.DataFiles.batch_delete(file_ids, opts)
QlikElixir.DataFiles.batch_change_space(file_ids, space_id, opts)
QlikElixir.DataFiles.get_quotas(opts)
QlikElixir.DataFiles.list_connections(opts)
```

### 1.6 QIX Engine (Data Extraction)

**Objective**: Extract data from Qlik visualizations via WebSocket.

This is the **core value proposition** - getting actual data out of Qlik apps.

**Architecture**:
```
lib/qlik_elixir/
├── qix/
│   ├── session.ex         # WebSocket connection management
│   ├── app.ex             # App-level operations (sheets, objects)
│   ├── hypercube.ex       # HyperCube data extraction
│   └── protocol.ex        # JSON-RPC message handling
```

**API**:
```elixir
# Session management
{:ok, session} = QlikElixir.QIX.connect(app_id, opts)
:ok = QlikElixir.QIX.disconnect(session)

# Navigation
{:ok, sheets} = QlikElixir.QIX.list_sheets(session)
{:ok, objects} = QlikElixir.QIX.list_objects(session, sheet_id)
{:ok, object} = QlikElixir.QIX.get_object(session, object_id)

# Data extraction (the main event)
{:ok, data} = QlikElixir.QIX.get_hypercube_data(session, object_id, opts)
# opts: page_size: 1000, max_rows: 10_000

# Returns:
%{
  headers: ["Country", "Sales", "Margin"],
  rows: [
    %{values: ["USA", 1_234_567, 0.23], text: ["USA", "$1.2M", "23%"]},
    %{values: ["Germany", 987_654, 0.19], text: ["Germany", "$987K", "19%"]},
    ...
  ],
  metadata: %{
    dimensions: [%{field: "Country", cardinality: 50}],
    measures: [%{label: "Sales", format: "money"}, %{label: "Margin", format: "percent"}]
  },
  total_rows: 50,
  truncated: false
}

# Streaming for large datasets
QlikElixir.QIX.stream_hypercube_data(session, object_id, opts)
|> Stream.each(&process_chunk/1)
|> Stream.run()

# Selections (filter data)
:ok = QlikElixir.QIX.select_values(session, field: "Country", values: ["USA", "Germany"])
:ok = QlikElixir.QIX.clear_selections(session)

# Custom expressions
{:ok, result} = QlikElixir.QIX.evaluate(session, "Sum(Sales)")
```

**Implementation Notes**:
- Use `mint_web_socket` or `gun` for WebSocket
- Handle reconnection gracefully
- Respect Qlik's rate limits and session timeouts
- Page through large datasets automatically

---

## Phase 2: Automation & Users

### 2.1 Users API

```elixir
QlikElixir.Users.list(opts)
QlikElixir.Users.create(params, opts)
QlikElixir.Users.get(user_id, opts)
QlikElixir.Users.update(user_id, params, opts)
QlikElixir.Users.delete(user_id, opts)
QlikElixir.Users.me(opts)                     # Current user
QlikElixir.Users.count(opts)
QlikElixir.Users.filter(query, opts)
QlikElixir.Users.invite(emails, opts)
```

### 2.2 API Keys API

```elixir
QlikElixir.APIKeys.list(opts)
QlikElixir.APIKeys.create(params, opts)
QlikElixir.APIKeys.get(key_id, opts)
QlikElixir.APIKeys.update(key_id, params, opts)
QlikElixir.APIKeys.delete(key_id, opts)
QlikElixir.APIKeys.get_config(tenant_id, opts)
QlikElixir.APIKeys.update_config(tenant_id, params, opts)
```

### 2.3 Automations API

```elixir
QlikElixir.Automations.list(opts)
QlikElixir.Automations.create(params, opts)
QlikElixir.Automations.get(automation_id, opts)
QlikElixir.Automations.update(automation_id, params, opts)
QlikElixir.Automations.delete(automation_id, opts)
QlikElixir.Automations.enable(automation_id, opts)
QlikElixir.Automations.disable(automation_id, opts)
QlikElixir.Automations.copy(automation_id, opts)
QlikElixir.Automations.change_owner(automation_id, owner_id, opts)
QlikElixir.Automations.change_space(automation_id, space_id, opts)

# Runs
QlikElixir.Automations.list_runs(automation_id, opts)
QlikElixir.Automations.run(automation_id, opts)
QlikElixir.Automations.get_run(automation_id, run_id, opts)
QlikElixir.Automations.stop_run(automation_id, run_id, opts)
QlikElixir.Automations.retry_run(automation_id, run_id, opts)

# Usage
QlikElixir.Automations.get_usage(opts)
```

### 2.4 Webhooks API

```elixir
QlikElixir.Webhooks.list(opts)
QlikElixir.Webhooks.create(params, opts)
QlikElixir.Webhooks.get(webhook_id, opts)
QlikElixir.Webhooks.update(webhook_id, params, opts)
QlikElixir.Webhooks.delete(webhook_id, opts)
QlikElixir.Webhooks.list_event_types(opts)

# Deliveries
QlikElixir.Webhooks.list_deliveries(webhook_id, opts)
QlikElixir.Webhooks.get_delivery(webhook_id, delivery_id, opts)
QlikElixir.Webhooks.resend_delivery(webhook_id, delivery_id, opts)
```

### 2.5 Data Connections API

```elixir
QlikElixir.DataConnections.list(opts)
QlikElixir.DataConnections.create(params, opts)
QlikElixir.DataConnections.get(connection_id, opts)
QlikElixir.DataConnections.update(connection_id, params, opts)
QlikElixir.DataConnections.delete(connection_id, opts)
QlikElixir.DataConnections.duplicate(connection_id, opts)
QlikElixir.DataConnections.batch_delete(connection_ids, opts)
QlikElixir.DataConnections.batch_update(updates, opts)
```

---

## Phase 3: Governance & Admin

### 3.1 Tenants API

```elixir
QlikElixir.Tenants.create(params, opts)
QlikElixir.Tenants.get(tenant_id, opts)
QlikElixir.Tenants.update(tenant_id, params, opts)
QlikElixir.Tenants.deactivate(tenant_id, opts)
QlikElixir.Tenants.reactivate(tenant_id, opts)
QlikElixir.Tenants.me(opts)
```

### 3.2 Groups API

```elixir
QlikElixir.Groups.list(opts)
QlikElixir.Groups.create(params, opts)
QlikElixir.Groups.get(group_id, opts)
QlikElixir.Groups.update(group_id, params, opts)
QlikElixir.Groups.delete(group_id, opts)
```

### 3.3 Roles API

```elixir
QlikElixir.Roles.list(opts)
QlikElixir.Roles.get(role_id, opts)
```

### 3.4 Audits API

```elixir
QlikElixir.Audits.list(opts)
QlikElixir.Audits.get(audit_id, opts)
# Streaming support for large audit logs
```

---

## Phase 4: Content & Advanced

### 4.1 Items API (Unified Resources)

```elixir
QlikElixir.Items.list(opts)
QlikElixir.Items.get(item_id, opts)
QlikElixir.Items.update(item_id, params, opts)
QlikElixir.Items.delete(item_id, opts)
```

### 4.2 Collections API

```elixir
QlikElixir.Collections.list(opts)
QlikElixir.Collections.create(params, opts)
QlikElixir.Collections.get(collection_id, opts)
QlikElixir.Collections.update(collection_id, params, opts)
QlikElixir.Collections.delete(collection_id, opts)
QlikElixir.Collections.add_items(collection_id, item_ids, opts)
QlikElixir.Collections.remove_items(collection_id, item_ids, opts)
```

### 4.3 Reports API

```elixir
QlikElixir.Reports.list(opts)
QlikElixir.Reports.create(params, opts)
QlikElixir.Reports.get(report_id, opts)
QlikElixir.Reports.download(report_id, opts)
```

### 4.4 Natural Language API

```elixir
QlikElixir.NaturalLanguage.ask(app_id, question, opts)
QlikElixir.NaturalLanguage.get_recommendations(app_id, opts)
```

---

## Phase 5: MCP Server

### 5.1 MCP Architecture

Create a standalone MCP server application that uses QlikElixir as its client:

```
qlik_mcp/
├── lib/
│   ├── qlik_mcp/
│   │   ├── server.ex           # MCP protocol handler
│   │   ├── tools/              # MCP tool definitions
│   │   │   ├── apps.ex
│   │   │   ├── spaces.ex
│   │   │   ├── data_files.ex
│   │   │   ├── reloads.ex
│   │   │   └── ...
│   │   └── resources/          # MCP resource definitions
│   └── qlik_mcp.ex
└── mix.exs                     # Depends on qlik_elixir
```

### 5.2 MCP Tools

**Data Extraction (Primary Value)**:
- `qlik_list_sheets` - List sheets in an app
- `qlik_list_charts` - List visualization objects on a sheet
- `qlik_get_chart_data` - **Extract data from a visualization** (dimensions, measures, rows)
- `qlik_query_data` - Extract data with custom filters/selections
- `qlik_evaluate_expression` - Calculate a Qlik expression (e.g., "Sum(Sales)")

**App Management**:
- `qlik_list_apps` - List all apps with filters
- `qlik_get_app` - Get app details and metadata
- `qlik_reload_app` - Trigger app data reload
- `qlik_get_reload_status` - Check reload progress

**Space & Files**:
- `qlik_list_spaces` - List all spaces
- `qlik_list_files` - List data files
- `qlik_upload_file` - Upload CSV/data file

**Automation**:
- `qlik_list_automations` - List automations
- `qlik_run_automation` - Trigger automation

### 5.3 MCP Resources

- `qlik://apps` - List of apps
- `qlik://apps/{id}` - App details
- `qlik://apps/{id}/sheets` - Sheets in an app
- `qlik://apps/{id}/sheets/{sheet_id}/objects` - Visualization objects on a sheet
- `qlik://spaces` - List of spaces
- `qlik://files` - List of data files

### 5.4 Example MCP Interaction

```
User: "What's our sales by country from the Q4 dashboard?"

Claude:
1. qlik_list_apps() → finds "Q4 Sales Dashboard" app
2. qlik_list_sheets(app_id) → finds "Regional Sales" sheet
3. qlik_list_charts(app_id, sheet_id) → finds "Sales by Country" table
4. qlik_get_chart_data(app_id, object_id) → extracts:

   | Country | Sales    | Margin |
   |---------|----------|--------|
   | USA     | $1.2M    | 23%    |
   | Germany | $987K    | 19%    |
   | UK      | $654K    | 21%    |
   ...

5. Claude analyzes and responds with insights
```

---

## Non-Functional Requirements

### Performance
- Connection pooling via Req
- Configurable timeouts
- Automatic retry with exponential backoff
- Rate limit handling (respect 429 responses)

### Security
- API keys stored securely (never logged)
- TLS 1.2+ required
- Input validation on all parameters

### Reliability
- Comprehensive error handling
- Graceful degradation
- Circuit breaker pattern for API failures

### Observability
- Telemetry events for all API calls
- Configurable logging levels
- Request/response timing metrics

### Documentation
- Complete HexDocs for all modules
- Usage examples for common workflows
- API reference links

---

## Success Metrics

| Metric | Target |
|--------|--------|
| API Coverage | 80%+ of Qlik REST APIs |
| Test Coverage | 90%+ |
| Documentation | 100% public functions documented |
| Hex Downloads | Track adoption |
| GitHub Stars | Community interest |

---

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| API changes | Version pinning, deprecation warnings |
| Rate limiting | Built-in rate limiter, configurable |
| Large responses | Streaming support, pagination |
| Auth complexity | Clear docs, examples, error messages |

---

## Appendix: API Reference Links

### QIX Engine (WebSocket)
- QIX Overview: https://qlik.dev/apis/json-rpc/qix/
- Global: https://qlik.dev/apis/json-rpc/qix/global/
- Doc (App): https://qlik.dev/apis/json-rpc/qix/doc/
- GenericObject: https://qlik.dev/apis/json-rpc/qix/genericobject/

### REST APIs
- Apps: https://qlik.dev/apis/rest/apps/
- Spaces: https://qlik.dev/apis/rest/spaces/
- Data Files: https://qlik.dev/apis/rest/data-files/
- Reloads: https://qlik.dev/apis/rest/reloads/
- Users: https://qlik.dev/apis/rest/users/
- API Keys: https://qlik.dev/apis/rest/api-keys/
- Automations: https://qlik.dev/apis/rest/automations/
- Webhooks: https://qlik.dev/apis/rest/webhooks/
- Data Connections: https://qlik.dev/apis/rest/data-connections/
- All REST APIs: https://qlik.dev/apis/rest/

### Reference Implementation
- qlik-mcp (TypeScript): https://github.com/jwaxman19/qlik-mcp
