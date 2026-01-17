defmodule QlikElixir.Uploader do
  @moduledoc """
  Core upload logic for CSV files to Qlik Cloud.
  """

  alias QlikElixir.{Client, Config, Error}
  alias QlikElixir.REST.Helpers

  @upload_endpoint "api/v1/data-files"

  @doc """
  Uploads a CSV file from a file path.
  """
  @spec upload_file(String.t(), Config.t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def upload_file(file_path, config, opts \\ []) do
    with {:ok, %{size: size}} <- Helpers.validate_file(file_path),
         :ok <- Helpers.validate_file_size(size),
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
    with :ok <- Helpers.validate_file_size(byte_size(content)),
         :ok <- Helpers.validate_filename(filename),
         {:ok, validated_config} <- Config.validate(config) do
      perform_upload(content, filename, validated_config, opts)
    end
  end

  defp perform_upload(content, filename, config, opts) do
    connection_id = opts[:connection_id] || config.connection_id
    multipart = build_multipart(content, filename, connection_id)

    case Client.post(@upload_endpoint, {:multipart, multipart}, config) do
      {:ok, _} = success ->
        success

      {:error, %Error{type: :file_exists_error}} = error ->
        maybe_overwrite(error, content, filename, config, opts)

      error ->
        error
    end
  end

  defp maybe_overwrite(error, content, filename, config, opts) do
    if Keyword.get(opts, :overwrite, false),
      do: handle_overwrite(content, filename, config, opts),
      else: error
  end

  defp handle_overwrite(content, filename, config, opts) do
    connection_id = opts[:connection_id] || config.connection_id

    with {:ok, existing_file} <- find_file_by_name(filename, config, connection_id),
         :ok <- delete_file(existing_file["id"], config) do
      perform_upload(content, filename, config, Keyword.put(opts, :overwrite, false))
    end
  end

  defp find_file_by_name(filename, config, connection_id) do
    query =
      []
      |> Helpers.add_param(:limit, 100)
      |> Helpers.add_param(:connectionId, connection_id)
      |> QlikElixir.Pagination.build_query()

    path = Helpers.build_path(@upload_endpoint, query)

    case Client.get(path, config) do
      {:ok, %{"data" => files}} ->
        case Enum.find(files, &(&1["name"] == filename)) do
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
    json_data =
      %{"name" => filename}
      |> Helpers.put_if_present("connectionId", connection_id)

    [
      {"Json", {Jason.encode!(json_data), [content_type: "application/json"]}},
      {"File", {content, [filename: filename, content_type: "text/csv"]}}
    ]
  end
end
