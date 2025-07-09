defmodule QlikElixir.Uploader do
  @moduledoc """
  Core upload logic for CSV files to Qlik Cloud.
  """

  alias QlikElixir.{Client, Config, Error}

  @max_file_size 500 * 1024 * 1024  # 500MB in bytes
  @upload_endpoint "api/v1/data-files"

  @doc """
  Uploads a CSV file from a file path.
  """
  @spec upload_file(String.t(), Config.t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def upload_file(file_path, config, opts \\ []) do
    with {:ok, %{size: size}} <- validate_file(file_path),
         :ok <- validate_file_size(size),
         {:ok, content} <- File.read(file_path),
         filename <- opts[:name] || Path.basename(file_path) do
      upload_content(content, filename, config, opts)
    end
  end

  @doc """
  Uploads CSV content directly.
  """
  @spec upload_content(binary(), String.t(), Config.t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def upload_content(content, filename, config, opts \\ []) do
    with :ok <- validate_file_size(byte_size(content)),
         :ok <- validate_filename(filename),
         {:ok, validated_config} <- Config.validate(config) do
      perform_upload(content, filename, validated_config, opts)
    end
  end

  defp perform_upload(content, filename, config, opts) do
    connection_id = opts[:connection_id] || config.connection_id
    
    multipart = build_multipart(content, filename, connection_id)
    
    case Client.post(@upload_endpoint, {:multipart, multipart}, config) do
      {:ok, response} ->
        {:ok, response}
        
      {:error, %Error{type: :file_exists_error}} = error ->
        if Keyword.get(opts, :overwrite, false) do
          handle_overwrite(content, filename, config, opts)
        else
          error
        end
        
      error ->
        error
    end
  end

  defp handle_overwrite(content, filename, config, opts) do
    with {:ok, existing_file} <- find_file_by_name(filename, config),
         :ok <- delete_file(existing_file["id"], config) do
      # Retry upload after deletion
      opts = Keyword.put(opts, :overwrite, false)
      perform_upload(content, filename, config, opts)
    end
  end

  defp find_file_by_name(filename, config) do
    case Client.get("#{@upload_endpoint}?limit=100", config) do
      {:ok, %{"data" => files}} ->
        case Enum.find(files, fn file -> file["name"] == filename end) do
          nil -> {:error, Error.file_not_found("File not found: #{filename}")}
          file -> {:ok, file}
        end
        
      error ->
        error
    end
  end

  defp delete_file(file_id, config) do
    case Client.delete("#{@upload_endpoint}/#{file_id}", config) do
      {:ok, _} -> :ok
      error -> error
    end
  end

  defp build_multipart(content, filename, connection_id) do
    parts = [
      {:file, content,
       filename: filename,
       content_type: "text/csv"}
    ]
    
    if connection_id do
      [{:field, "connectionId", connection_id} | parts]
    else
      parts
    end
  end

  defp validate_file(file_path) do
    case File.stat(file_path) do
      {:ok, stat} ->
        if stat.type == :regular do
          {:ok, stat}
        else
          {:error, Error.validation_error("#{file_path} is not a regular file")}
        end
        
      {:error, :enoent} ->
        {:error, Error.file_not_found("File not found: #{file_path}")}
        
      {:error, reason} ->
        {:error, Error.validation_error("Cannot access file: #{inspect(reason)}")}
    end
  end

  defp validate_file_size(size) when size > @max_file_size do
    {:error, Error.file_too_large("File size (#{format_bytes(size)}) exceeds maximum allowed size (#{format_bytes(@max_file_size)})")}
  end

  defp validate_file_size(_), do: :ok

  defp validate_filename(filename) do
    if String.ends_with?(filename, ".csv") do
      :ok
    else
      {:error, Error.validation_error("Filename must end with .csv extension")}
    end
  end

  defp format_bytes(bytes) do
    cond do
      bytes >= 1024 * 1024 * 1024 -> "#{Float.round(bytes / (1024 * 1024 * 1024), 2)} GB"
      bytes >= 1024 * 1024 -> "#{Float.round(bytes / (1024 * 1024), 2)} MB"
      bytes >= 1024 -> "#{Float.round(bytes / 1024, 2)} KB"
      true -> "#{bytes} B"
    end
  end
end