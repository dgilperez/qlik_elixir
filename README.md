# QlikElixir

An Elixir client library for uploading CSV files to Qlik Cloud with comprehensive API support.

## Features

- Upload CSV files to Qlik Cloud using multipart form data
- Support for both file path and binary content uploads
- Automatic overwrite handling with delete-and-retry logic
- File size validation (500MB limit)
- Comprehensive error handling with custom error types
- Support for multiple tenant configurations
- Built-in retry logic and configurable timeouts
- Full test coverage with mocked HTTP interactions

## Installation

Add `qlik_elixir` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:qlik_elixir, "~> 0.1.0"}
  ]
end
```

Then run:

```bash
mix deps.get
```

## Configuration

### Environment Variables

The simplest way to configure QlikElixir is through environment variables:

```bash
export QLIK_API_KEY="your-api-key"
export QLIK_TENANT_URL="https://your-tenant.qlikcloud.com"
export QLIK_CONNECTION_ID="your-connection-id"  # Optional
```

### Application Configuration

You can also configure it in your `config/config.exs`:

```elixir
config :qlik_elixir,
  api_key: "your-api-key",
  tenant_url: "https://your-tenant.qlikcloud.com",
  connection_id: "your-connection-id"  # Optional
```

### Runtime Configuration

For runtime configuration or multiple tenants:

```elixir
config = QlikElixir.new_config(
  api_key: "different-key",
  tenant_url: "https://other-tenant.qlikcloud.com",
  connection_id: "space-123",
  http_options: [timeout: 60_000]  # 1 minute timeout
)

QlikElixir.upload_csv("data.csv", config: config)
```

## Usage

### Basic File Upload

```elixir
# Upload a CSV file
{:ok, %{"id" => file_id}} = QlikElixir.upload_csv("path/to/data.csv")

# Upload with custom name
{:ok, file} = QlikElixir.upload_csv("data.csv", name: "renamed_file.csv")

# Upload with overwrite
{:ok, file} = QlikElixir.upload_csv("data.csv", overwrite: true)

# Upload to specific connection
{:ok, file} = QlikElixir.upload_csv("data.csv", connection_id: "space-123")
```

### Upload Content Directly

```elixir
# Create CSV content dynamically
csv_content = "id,name,email\n1,John Doe,john@example.com\n2,Jane Smith,jane@example.com"

# Upload the content
{:ok, file} = QlikElixir.upload_csv_content(csv_content, "users.csv")

# With options
{:ok, file} = QlikElixir.upload_csv_content(
  csv_content, 
  "users.csv",
  connection_id: "space-456",
  overwrite: true
)
```

### List Files

```elixir
# List all files (up to 100)
{:ok, %{"data" => files, "total" => total}} = QlikElixir.list_files()

# With pagination
{:ok, result} = QlikElixir.list_files(limit: 20, offset: 40)
```

### Check File Existence

```elixir
# Check if a file exists by name
if QlikElixir.file_exists?("important_data.csv") do
  IO.puts("File already exists!")
end
```

### Find File by Name

```elixir
case QlikElixir.find_file_by_name("sales_data.csv") do
  {:ok, file} ->
    IO.puts("Found file with ID: #{file["id"]}")
  
  {:error, _} ->
    IO.puts("File not found")
end
```

### Delete Files

```elixir
# Delete by file ID
case QlikElixir.delete_file("file-id-123") do
  :ok ->
    IO.puts("File deleted successfully")
  
  {:error, error} ->
    IO.puts("Failed to delete: #{error.message}")
end
```

## Advanced Usage

### Custom Configuration per Request

```elixir
# Create a custom config for a specific tenant
eu_config = QlikElixir.new_config(
  api_key: System.get_env("EU_QLIK_API_KEY"),
  tenant_url: "https://eu-tenant.qlikcloud.com"
)

# Use it for specific operations
{:ok, file} = QlikElixir.upload_csv("eu_data.csv", config: eu_config)
{:ok, files} = QlikElixir.list_files(config: eu_config)
```

### Error Handling

QlikElixir provides detailed error information:

```elixir
case QlikElixir.upload_csv("data.csv") do
  {:ok, file} ->
    IO.puts("Uploaded successfully: #{file["id"]}")
  
  {:error, %QlikElixir.Error{} = error} ->
    case error.type do
      :file_exists_error ->
        IO.puts("File already exists. Use overwrite: true to replace it.")
      
      :file_too_large ->
        IO.puts("File is too large. Maximum size is 500MB.")
      
      :authentication_error ->
        IO.puts("Invalid API key. Please check your configuration.")
      
      :validation_error ->
        IO.puts("Validation failed: #{error.message}")
      
      _ ->
        IO.puts("Upload failed: #{error.message}")
    end
end
```

### Batch Operations

```elixir
# Upload multiple files
files = ["data1.csv", "data2.csv", "data3.csv"]

results = Enum.map(files, fn file ->
  case QlikElixir.upload_csv(file) do
    {:ok, result} -> {:ok, file, result["id"]}
    {:error, error} -> {:error, file, error}
  end
end)

# Process results
Enum.each(results, fn
  {:ok, file, id} -> IO.puts("✓ #{file} uploaded as #{id}")
  {:error, file, error} -> IO.puts("✗ #{file} failed: #{error.message}")
end)
```

### Progress Monitoring

For large file uploads, you might want to show progress:

```elixir
defmodule UploadProgress do
  def upload_with_progress(file_path) do
    %{size: file_size} = File.stat!(file_path)
    
    IO.puts("Uploading #{Path.basename(file_path)} (#{format_bytes(file_size)})...")
    
    case QlikElixir.upload_csv(file_path) do
      {:ok, result} ->
        IO.puts("✓ Upload complete! File ID: #{result["id"]}")
        {:ok, result}
      
      {:error, error} ->
        IO.puts("✗ Upload failed: #{error.message}")
        {:error, error}
    end
  end
  
  defp format_bytes(bytes) when bytes < 1024, do: "#{bytes} B"
  defp format_bytes(bytes) when bytes < 1024 * 1024, do: "#{Float.round(bytes / 1024, 1)} KB"
  defp format_bytes(bytes), do: "#{Float.round(bytes / (1024 * 1024), 1)} MB"
end
```

## HTTP Options

You can customize HTTP behavior through configuration:

```elixir
config = QlikElixir.new_config(
  api_key: "your-key",
  tenant_url: "https://your-tenant.qlikcloud.com",
  http_options: [
    timeout: :timer.minutes(10),     # 10 minute timeout for large files
    retry: :transient,               # Retry on transient errors
    max_retries: 5,                  # Maximum number of retries
    retry_delay: fn n -> n * 2000 end # Exponential backoff
  ]
)
```

## Error Types

QlikElixir defines the following error types:

- `:validation_error` - Invalid input parameters
- `:upload_error` - General upload failure
- `:authentication_error` - Invalid or missing API key
- `:configuration_error` - Invalid configuration
- `:file_exists_error` - File already exists (when overwrite is false)
- `:file_not_found` - File or resource not found
- `:file_too_large` - File exceeds 500MB limit
- `:network_error` - Network connectivity issues
- `:unknown_error` - Unexpected errors

## Testing

Run the test suite:

```bash
mix test
```

Run with coverage:

```bash
mix coveralls.html
```

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- Built with [Req](https://hexdocs.pm/req) for HTTP client functionality
- Inspired by the Qlik Cloud API documentation
- Thanks to the Elixir community for the amazing ecosystem