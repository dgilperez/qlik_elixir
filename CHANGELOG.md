# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

[Unreleased]: https://github.com/dgilperez/qlik_elixir/compare/v0.3.4...HEAD
[0.3.4]: https://github.com/dgilperez/qlik_elixir/compare/v0.3.3...v0.3.4
[0.3.3]: https://github.com/dgilperez/qlik_elixir/compare/v0.3.2...v0.3.3
[0.3.2]: https://github.com/dgilperez/qlik_elixir/compare/v0.3.1...v0.3.2
[0.3.1]: https://github.com/dgilperez/qlik_elixir/compare/v0.3.0...v0.3.1
[0.3.0]: https://github.com/dgilperez/qlik_elixir/compare/v0.2.2...v0.3.0
[0.2.2]: https://github.com/dgilperez/qlik_elixir/compare/v0.2.1...v0.2.2
[0.2.1]: https://github.com/dgilperez/qlik_elixir/compare/v0.2.0...v0.2.1
[0.2.0]: https://github.com/dgilperez/qlik_elixir/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/dgilperez/qlik_elixir/releases/tag/v0.1.0