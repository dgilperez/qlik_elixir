# QlikElixir - Elixir Client for Qlik Cloud APIs

## Project Overview

Comprehensive Elixir client for Qlik Cloud REST APIs and QIX Engine. Supports 16+ REST API modules and WebSocket-based QIX Engine for data extraction.

- **Package**: [hex.pm/packages/qlik_elixir](https://hex.pm/packages/qlik_elixir)
- **Repository**: [github.com/dgilperez/qlik_elixir](https://github.com/dgilperez/qlik_elixir)
- **License**: MIT
- **Status**: Active development (v0.3.x)

## Tech Stack

- **Language**: Elixir 1.18+
- **HTTP Client**: Req
- **JSON**: Jason
- **Testing**: ExUnit with Bypass for HTTP mocking
- **Quality**: Credo, Dialyzer
- **Documentation**: ExDoc

## Project Structure

```
qlik_elixir/
├── lib/
│   └── qlik_elixir/
│       ├── client.ex      # HTTP client wrapper
│       ├── config.ex      # Configuration management
│       ├── error.ex       # Error types
│       └── uploader.ex    # File upload logic
│   └── qlik_elixir.ex     # Public API facade
├── test/
│   ├── qlik_elixir/       # Unit tests
│   └── qlik_elixir_test.exs
├── config/
├── .credo.exs
└── mix.exs
```

## Architecture Principles

### Module Organization

Each Qlik API category should have its own module under `QlikElixir.*`:

```elixir
QlikElixir              # Public facade - delegates to specific modules
QlikElixir.Client       # Low-level HTTP client (internal)
QlikElixir.Config       # Configuration struct
QlikElixir.Error        # Error types
QlikElixir.DataFiles    # Data Files API (current)
QlikElixir.Apps         # Apps API (future)
QlikElixir.Spaces       # Spaces API (future)
# ... more API modules
```

### API Module Pattern

Each API module should follow this structure:

```elixir
defmodule QlikElixir.SomeApi do
  @moduledoc """
  Qlik Cloud Some API client.

  API Reference: https://qlik.dev/apis/rest/some-api/
  """

  alias QlikElixir.{Client, Config, Error}

  @base_path "api/v1/some-resource"

  # Public API functions with @doc and @spec
  @doc "Lists resources with pagination support."
  @spec list(keyword()) :: {:ok, map()} | {:error, Error.t()}
  def list(opts \\ [])

  @doc "Gets a single resource by ID."
  @spec get(String.t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def get(id, opts \\ [])

  @doc "Creates a new resource."
  @spec create(map(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def create(params, opts \\ [])

  # etc.
end
```

## Elixir Conventions

### Code Style

- Follow official Elixir style guide
- Use `mix format` before every commit
- Zero `mix credo --strict` warnings
- Zero Dialyzer warnings
- Prefer pattern matching over conditionals
- Keep functions small and focused (< 20 lines)
- Use pipes for data transformations
- Explicit > implicit

### Module Template

```elixir
defmodule QlikElixir.MyModule do
  @moduledoc """
  One-line description.

  ## Overview

  Detailed explanation if needed.

  ## Examples

      iex> QlikElixir.MyModule.example()
      {:ok, result}
  """

  # 1. use/import/alias/require (alphabetical within groups)
  alias QlikElixir.{Client, Config, Error}

  require Logger

  # 2. Module attributes
  @base_path "api/v1/resource"

  # 3. Type definitions
  @type t :: %__MODULE__{}

  # 4. Public API (def) with @doc and @spec

  # 5. Private functions (defp)
end
```

### Naming Conventions

- Modules: `PascalCase`
- Functions/variables: `snake_case`
- Atoms: `snake_case`
- Constants (module attributes): `@snake_case`
- API paths: Match Qlik's naming (e.g., `data-files` -> `DataFiles`)

### Error Handling

- Use tagged tuples: `{:ok, result}` / `{:error, %Error{}}`
- All errors should use `QlikElixir.Error` struct
- Map HTTP errors to appropriate error types
- Never silently swallow errors

```elixir
# Good
def fetch_resource(id, opts \\ []) do
  config = get_config(opts)

  case Client.get("#{@base_path}/#{id}", config) do
    {:ok, data} -> {:ok, data}
    {:error, _} = error -> error
  end
end

# Bad - don't rescue blindly
def fetch_resource(id) do
  try do
    # ...
  rescue
    _ -> {:error, :unknown}
  end
end
```

### Testing

- 90%+ test coverage target
- Use ExUnit with descriptive test names
- Use Bypass for HTTP mocking (no real API calls in tests)
- Test both success and error paths
- Integration tests should be optional and skip by default

```elixir
describe "list/1" do
  test "returns resources when API responds successfully" do
    Bypass.expect(bypass, "GET", "/api/v1/resources", fn conn ->
      Plug.Conn.resp(conn, 200, ~s({"data": [], "total": 0}))
    end)

    assert {:ok, %{"data" => [], "total" => 0}} = SomeApi.list()
  end

  test "returns error when API returns 401" do
    Bypass.expect(bypass, "GET", "/api/v1/resources", fn conn ->
      Plug.Conn.resp(conn, 401, ~s({"message": "Unauthorized"}))
    end)

    assert {:error, %Error{type: :authentication_error}} = SomeApi.list()
  end
end
```

### Documentation

- `@moduledoc` on every public module
- `@doc` on every public function
- `@spec` on every public function
- Include examples in docs
- Link to Qlik API reference where applicable

## Current Implementation Status

### Implemented (v0.2.x)

- **Data Files API** (partial)
  - `list_files/1` - List files with pagination
  - `upload_csv/2` - Upload CSV file from path
  - `upload_csv_content/3` - Upload CSV from binary
  - `delete_file/2` - Delete file by ID
  - `file_exists?/2` - Check if file exists
  - `find_file_by_name/2` - Find file by name

### Not Yet Implemented

See PRD.md for full roadmap of planned API coverage.

## Configuration

The library supports three configuration methods:

1. **Environment variables** (default)
   ```
   QLIK_API_KEY, QLIK_TENANT_URL, QLIK_CONNECTION_ID
   ```

2. **Application config**
   ```elixir
   config :qlik_elixir,
     api_key: "...",
     tenant_url: "https://tenant.qlikcloud.com"
   ```

3. **Runtime config** (per-request)
   ```elixir
   config = QlikElixir.new_config(api_key: "...", tenant_url: "...")
   QlikElixir.list_files(config: config)
   ```

## Development Commands

```bash
# Setup
mix deps.get

# Quality
mix format
mix credo --strict
mix dialyzer

# Testing
mix test
mix test --cover

# Documentation
mix docs
open doc/index.html

# Publishing (maintainers only)
mix hex.publish
```

## Release Process

Follow these steps when releasing a new version:

1. **Update version** in `mix.exs`
   ```elixir
   @version "X.Y.Z"
   ```

2. **Update CHANGELOG.md**
   - Add new version section with date
   - Document all changes (Added, Changed, Fixed, Removed)
   - Update comparison links at bottom

3. **Run quality checks**
   ```bash
   mix format
   mix credo --strict
   mix test
   ```

4. **Commit and push**
   ```bash
   git add -A
   git commit -m "Bump version to X.Y.Z"
   git push
   ```

5. **Publish to Hex.pm**
   ```bash
   mix hex.publish
   ```

6. **Create GitHub release** (optional)
   - Tag: `vX.Y.Z`
   - Copy changelog section as release notes

## Contributing Guidelines

1. Fork the repository
2. Create feature branch from `master`
3. Write tests first (TDD preferred)
4. Ensure all quality checks pass
5. Submit PR with clear description

## Qlik API Reference

- **Developer Portal**: https://qlik.dev/
- **REST APIs**: https://qlik.dev/apis/rest/
- **Authentication**: API keys via `Authorization: Bearer <key>` header
- **Rate Limits**: Tier 1 (1000 req/min) and Tier 2 (100 req/min)
- **Base URL Pattern**: `https://{tenant}.{region}.qlikcloud.com/api/v1/`

## Important Notes

- This is an open source project - no private/sensitive info in commits
- Keep dependencies minimal for a library
- Maintain backwards compatibility within major versions
- Follow semantic versioning strictly
