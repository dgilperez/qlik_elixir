# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

[Unreleased]: https://github.com/dgilperez/qlik_elixir/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/dgilperez/qlik_elixir/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/dgilperez/qlik_elixir/releases/tag/v0.1.0