defmodule QlikElixir.REST.ReportTemplates do
  @moduledoc """
  Qlik Cloud Report Templates REST API client.

  Report templates are the stored Excel, Word, PowerPoint or pixel-perfect files
  that `QlikElixir.REST.Reports` renders against an app. Unlike the report requests
  themselves, templates *are* stored resources: they can be listed, updated and
  deleted.

  A template is created from a file previously uploaded as temporary content, which
  is why `create/2` takes a `temporaryContentId` rather than a path.

  ## Examples

      {:ok, %{"data" => templates}} = ReportTemplates.list(name: "ventas", config: config)
      {:ok, template} = ReportTemplates.get(id, config: config)
      {:ok, xlsx} = ReportTemplates.download(id, config: config)

  API reference: https://qlik.dev/apis/rest/report-templates/
  """

  alias QlikElixir.{Client, Error}
  alias QlikElixir.REST.Helpers

  @base_path "api/v1/report-templates"

  @doc """
  Lists report templates.

  This endpoint pages by offset, not by cursor: use `:skip`, not a `next` token.

  ## Options

    * `:limit` - Page size, 1..100 (default: 20)
    * `:skip` - Number of templates to skip (default: 0)
    * `:name` - Case-insensitive wildcard search on the name
    * `:owner_id` - Filter by owner
    * `:source_app_id` - Filter by the app the template was built from
    * `:sort` - `name`, `createdAt`, `updatedAt` or `type`, optionally prefixed
      with `+`/`-`; a list is accepted
    * `:config` - Custom configuration

  ## Examples

      iex> QlikElixir.REST.ReportTemplates.list(limit: 50, sort: "-updatedAt")
      {:ok, %{"data" => [...]}}

  """
  @spec list(keyword()) :: {:ok, map()} | {:error, Error.t()}
  def list(opts \\ []) do
    query =
      Helpers.build_query(
        opts,
        [
          {:skip, :skip},
          {:name, :name},
          {:ownerId, :owner_id},
          {:sourceAppId, :source_app_id},
          {:sort, :sort}
        ],
        [{:limit, :limit}]
      )

    @base_path
    |> Helpers.build_path(query)
    |> Client.get(Helpers.get_config(opts))
  end

  @doc """
  Gets a report template by ID.
  """
  @spec get(String.t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def get(template_id, opts \\ []) do
    "#{@base_path}/#{template_id}"
    |> Client.get(Helpers.get_config(opts))
    |> Helpers.normalize_get_response("Report template")
  end

  @doc """
  Creates a report template from a file held as temporary content.

  ## Parameters

    * `:name` - Required. 1..255 characters.
    * `:temporary_content_id` - Required. The uploaded template file.
    * `:description` - Up to 255 characters.
    * `:source_app_id` - The app the template reports on.
    * `:source_app_action` - `"validate"` (default) or `"replace"`.

  ## Examples

      iex> ReportTemplates.create(%{name: "Ventas", temporary_content_id: "653bb4ac..."})
      {:ok, %{"id" => "223940f7-...", "name" => "Ventas"}}

  """
  @spec create(map(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def create(params, opts \\ []) do
    Client.post(@base_path, build_body(params), Helpers.get_config(opts))
  end

  @doc """
  Replaces a report template.

  Takes the same fields as `create/2` except `:source_app_id`, which cannot be
  changed once the template exists.
  """
  @spec update(String.t(), map(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def update(template_id, params, opts \\ []) do
    Client.put("#{@base_path}/#{template_id}", build_body(params), Helpers.get_config(opts))
  end

  @doc """
  Patches a report template with a JSON Patch document (RFC 6902).

  ## Examples

      iex> ReportTemplates.patch(id, [%{op: "replace", path: "/name", value: "Ventas 2026"}])
      :ok

  """
  @spec patch(String.t(), list(map()), keyword()) :: :ok | {:error, Error.t()}
  def patch(template_id, operations, opts \\ []) when is_list(operations) do
    "#{@base_path}/#{template_id}"
    |> Client.patch(operations, Helpers.get_config(opts))
    |> Helpers.normalize_delete_response("Report template")
  end

  @doc """
  Deletes a report template.
  """
  @spec delete(String.t(), keyword()) :: :ok | {:error, Error.t()}
  def delete(template_id, opts \\ []) do
    "#{@base_path}/#{template_id}"
    |> Client.delete(Helpers.get_config(opts))
    |> Helpers.normalize_delete_response("Report template")
  end

  @doc """
  Downloads the template file.

  Returns the raw bytes of the stored Office document.
  """
  @spec download(String.t(), keyword()) :: {:ok, binary()} | {:error, Error.t()}
  def download(template_id, opts \\ []) do
    "#{@base_path}/#{template_id}/actions/download"
    |> Client.post(%{}, Helpers.get_config(opts), decode_body: false)
    |> Helpers.normalize_get_response("Report template")
  end

  defp build_body(params) do
    Helpers.build_body(params, [
      :name,
      :description,
      {"sourceAppId", :source_app_id},
      {"sourceAppAction", :source_app_action},
      {"temporaryContentId", :temporary_content_id}
    ])
  end
end
