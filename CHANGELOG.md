# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.4.0] - 2026-09-05

### Fixed
- `Client` - A `429 Too Many Requests` was reported as an `:upload_error`, leaving
  `Error.rate_limit_error/2` unreachable. It now returns `:rate_limit_error` and
  carries the `Retry-After` header in `details`. This matters for the Reporting
  API, which Qlik caps at 10 requests per minute.
- `Reports` - The module was built against endpoints that do not exist. Verified
  against the live Reporting API and rewritten around its three real operations:
  - `create/2` now returns the `202 Accepted` payload (`requestId`, `outputsUrl`)
  - `get_status/2` unchanged, now documented with Qlik's real status values
  - `list_outputs/2` replaces the invented `download/2`; pages with `:page`
    (the API has no `next` cursor here) and accepts `:filter` and `:sort`
  - Removed `list/1`, `get/2` and `delete/2` — the API has no listing, no
    fetch-by-id and no delete for report requests. `list/1` returning 404 is what
    the README described as a missing entitlement; it was this bug.

### Added
- `Reports.await/2` - Polls a request to a terminal status, with `:interval` and
  `:timeout`, both validated rather than left to crash in `Process.sleep/1`
- `Reports.generate/2` - Queue, wait and return the outputs in one call
- `Reports.download_output/2` - Fetches the produced file from its temporary
  content location
- `ReportTemplates` - New module for the Report Templates API: `list/1`, `get/2`,
  `create/2`, `update/3`, `patch/3`, `delete/2`, `download/2`
- `Helpers.join_param/1` - Comma-joins repeatable query parameters
- `Error` - `:timeout` and `:report_failed` types, with `timeout_error/2` and
  `report_failed/2`

### Changed
- **Breaking**: `Reports.list/1`, `Reports.get/2`, `Reports.delete/2` and
  `Reports.download/2` are gone. `download/2` becomes `download_output/2` and
  takes an output (or its location), not a request id.
- `Helpers.build_query/2` becomes `build_query/3`: the third argument overrides
  the `limit`/`next` base for endpoints that page differently. Query parameters
  now come out in the order they are declared rather than reversed, which changes
  the query string of every listing endpoint (the parameters and their values are
  unchanged). List values are comma-joined, so repeatable parameters such as
  `sort` accept a list.
- `Client.patch/4` accepted a list at runtime but declared `map()`; the spec now
  admits the JSON Patch documents Qlik's patch endpoints require.
- `Helpers` documentation examples were never executable — they showed placeholder
  structs and a module-local alias. They are real doctests now and run in CI.
- `guides/rest-apis.md` documented the removed `Reports.list/0` and
  `Reports.download/1`; rewritten for the asynchronous flow and the new
  Report Templates module.

## [0.3.5] - 2025-01-18

### Fixed
- `explore_qlik.exs` - Updated to use correct NaturalLanguage API functions:
  - Replaced `get_fields/2` with `list_analysis_types/2`
  - Replaced `get_recommendations/2` with `recommend/3`
  - Fixed `APIKeys.get_config` to pass required `tenant_id` parameter

## [0.3.4] - 2025-01-18

### Fixed
- `NaturalLanguage` - Corrected API endpoints to match Qlik's actual API:
  - `ask/3` now uses `/actions/recommend` (was `/actions/ask`)
  - Added `recommend/3` for field-based recommendations
  - Added `list_analysis_types/2` for available analysis types
  - Removed non-existent `get_fields/2` and `get_recommendations/2`

## [0.3.3] - 2025-01-18

### Fixed
- `Collections.add_item` - Fixed to use `{"id": item_id}` format (API requires single item)
- `Collections.add_items` - Now iterates calling `add_item` for each item

### Added
- `Items.find_by_resource/3` - Helper to lookup item by resource ID and type
- `Items.list` - Added `:resource_id` filter option

## [0.3.2] - 2025-01-18

### Fixed
- `Spaces.update` - Fixed to use JSON Patch format required by Qlik API
- `Client` - Added JSON encoding for list request bodies

## [0.3.1] - 2025-01-17

### Fixed
- `Apps.get_script` - Fixed endpoint path from `/script` to `/scripts`
- `APIKeys.get_config` - Changed to require tenant_id parameter
- `APIKeys.update_config` - Changed to require tenant_id parameter

## [0.3.0] - 2025-01-17

### Added

**QIX Engine Support (WebSocket)**
- New `QlikElixir.QIX.Session` module for WebSocket connection management
- New `QlikElixir.QIX.App` module for high-level data extraction API
  - `list_sheets/2` - List all sheets in an app
  - `list_objects/3` - List visualization objects on a sheet
  - `get_object/3` - Get object handle
  - `get_layout/3` - Get object layout
  - `get_hypercube_data/3` - Extract data from visualizations with pagination
  - `stream_hypercube_data/3` - Stream large datasets
  - `select_values/4` - Make selections in fields
  - `clear_selections/2` - Clear all selections
  - `evaluate/3` - Evaluate Qlik expressions
- New `QlikElixir.QIX.Protocol` module for JSON-RPC protocol handling

**REST API Modules**
- `QlikElixir.REST.Apps` - Full Apps API with publish, export, import, scripts, media
- `QlikElixir.REST.Spaces` - Spaces and role assignments
- `QlikElixir.REST.Reloads` - Trigger and monitor app reloads
- `QlikElixir.REST.Users` - User management including invitations
- `QlikElixir.REST.Groups` - Group management
- `QlikElixir.REST.APIKeys` - API key management
- `QlikElixir.REST.Automations` - Automation workflows and runs
- `QlikElixir.REST.Webhooks` - Event notifications and deliveries
- `QlikElixir.REST.DataConnections` - External data sources
- `QlikElixir.REST.Items` - Unified resource listing
- `QlikElixir.REST.Collections` - Content organization and favorites
- `QlikElixir.REST.Reports` - Report generation and download
- `QlikElixir.REST.Tenants` - Tenant configuration
- `QlikElixir.REST.Roles` - Role definitions
- `QlikElixir.REST.Audits` - Audit event logging
- `QlikElixir.REST.NaturalLanguage` - Conversational analytics (Insight Advisor)

**Data Files API Enhancements**
- `change_owner/3` - Change file owner
- `change_space/3` - Move file to another space
- `batch_delete/2` - Delete multiple files
- `batch_change_space/3` - Move multiple files
- `get_quotas/1` - Get storage quotas
- `list_connections/1` - List available connections

**Infrastructure**
- `QlikElixir.Pagination` module for cursor-based pagination
- `QlikElixir.REST.Helpers` for shared REST API utilities
- Comprehensive documentation with guides
- 360+ tests with full coverage

### Changed
- Reorganized codebase under `QlikElixir.REST.*` and `QlikElixir.QIX.*` namespaces
- Updated package description
- Improved error handling across all modules

## [0.2.2] - 2025-01-12

### Fixed
- Fixed overwrite functionality to properly respect connection_id filter
  - The `handle_overwrite` function now passes connection_id to `find_file_by_name`
  - File search is now filtered by connection_id when provided, preventing cross-space file conflicts
- Added support for `includeAllSpaces` option in `list_files` function
  - Allows listing files across all spaces when set to true

## [0.2.1] - 2025-01-11

### Fixed
- Fixed multipart form structure to match Qlik Cloud API requirements
  - Multipart form now uses 'File' and 'Json' fields (capitalized) as required by Qlik API
  - The 'Json' field contains metadata including the 'name' parameter as a JSON object
  - This fixes upload failures with "Request must contain 'name' parameter" error
- Updated tests to properly verify the multipart form structure

## [0.2.0] - 2025-01-10

### Fixed
- Fixed multipart form upload format to be compatible with Req library
  - File options are now properly wrapped in a list: `{content, [filename: filename, content_type: "text/csv"]}`
  - This ensures proper multipart form encoding when uploading CSV files to Qlik Cloud

## [0.1.0] - 2024-01-01

### Added
- Initial release of QlikElixir
- Core upload functionality for CSV files to Qlik Cloud
- Support for file path and binary content uploads
- Automatic overwrite handling with delete-and-retry logic
- File size validation (500MB limit)
- Comprehensive error handling with custom error types
- List files with pagination support
- Delete files by ID
- Check file existence by name
- Find file by name
- Support for environment variables configuration
- Support for runtime configuration override
- Support for multiple tenant configurations
- Configurable HTTP client options (timeout, retry)
- Full test coverage with Bypass for HTTP mocking
- Comprehensive documentation and examples

[Unreleased]: https://github.com/dgilperez/qlik_elixir/compare/v0.3.5...HEAD
[0.3.5]: https://github.com/dgilperez/qlik_elixir/compare/v0.3.4...v0.3.5
[0.3.4]: https://github.com/dgilperez/qlik_elixir/compare/v0.3.3...v0.3.4
[0.3.3]: https://github.com/dgilperez/qlik_elixir/compare/v0.3.2...v0.3.3
[0.3.2]: https://github.com/dgilperez/qlik_elixir/compare/v0.3.1...v0.3.2
[0.3.1]: https://github.com/dgilperez/qlik_elixir/compare/v0.3.0...v0.3.1
[0.3.0]: https://github.com/dgilperez/qlik_elixir/compare/v0.2.2...v0.3.0
[0.2.2]: https://github.com/dgilperez/qlik_elixir/compare/v0.2.1...v0.2.2
[0.2.1]: https://github.com/dgilperez/qlik_elixir/compare/v0.2.0...v0.2.1
[0.2.0]: https://github.com/dgilperez/qlik_elixir/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/dgilperez/qlik_elixir/releases/tag/v0.1.0