defmodule QlikElixir.REST.NaturalLanguage do
  @moduledoc """
  REST API client for Qlik Cloud Natural Language (Insight Advisor).

  Enables natural language queries and AI-powered analytics recommendations
  for Qlik apps.

  ## Examples

      # Ask a question
      {:ok, response} = NaturalLanguage.ask("app-123", "What were total sales?", config: config)

      # Continue a conversation
      {:ok, response} = NaturalLanguage.ask(
        "app-123",
        "Show by region",
        config: config,
        conversation_id: "conv-123"
      )

      # Get analysis recommendations
      {:ok, %{"recommendations" => recs}} = NaturalLanguage.get_recommendations("app-123", config: config)

      # Get available fields for NL queries
      {:ok, %{"fields" => fields}} = NaturalLanguage.get_fields("app-123", config: config)

  """

  alias QlikElixir.{Client, Error}
  alias QlikElixir.REST.Helpers

  @doc """
  Gets analysis recommendations based on natural language or field selections.

  ## Parameters

    * `app_id` - The app ID to query.
    * `request` - Map with recommendation request:
      * `:text` - Natural language question (optional if fields provided).
      * `:fields` - List of field/master item selections (optional if text provided).
      * `:target_analysis` - Preferred analysis type (optional).

  ## Options

    * `:config` - Required. The configuration struct.
    * `:lang` - Language code (e.g., "en", "es") via Accept-Language header.

  ## Returns

  A response containing recommended analyses based on the app's data model.

  ## Supported Analysis Types

  "breakdown", "changePoint", "comparison", "contribution", "correlation",
  "fact", "mutualInfo", "rank", "spike", "trend", "values"

  ## Examples

      # Natural language question
      {:ok, response} = NaturalLanguage.recommend("app-123", %{text: "show sales by region"}, config: config)

      # Field-based recommendation
      {:ok, response} = NaturalLanguage.recommend("app-123", %{
        fields: [%{name: "Sales", type: "measure"}, %{name: "Region", type: "dimension"}]
      }, config: config)

  """
  @spec recommend(String.t(), map(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def recommend(app_id, request, opts \\ []) do
    path = "api/v1/apps/#{app_id}/insight-analyses/actions/recommend"
    Client.post(path, request, Helpers.get_config(opts))
  end

  @doc """
  Asks a natural language question about an app's data.

  This is a convenience wrapper around `recommend/3` for simple text queries.

  ## Parameters

    * `app_id` - The app ID to query.
    * `question` - The natural language question.

  ## Options

    * `:config` - Required. The configuration struct.
    * `:lang` - Language code for the question (e.g., "en", "es").

  ## Examples

      {:ok, response} = NaturalLanguage.ask("app-123", "What were total sales?", config: config)

  """
  @spec ask(String.t(), String.t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def ask(app_id, question, opts \\ []) do
    recommend(app_id, %{"text" => question}, opts)
  end

  @doc """
  Lists available analysis types for an app.

  Returns information about analysis types (breakdown, trend, comparison, etc.)
  that can be used with the app's data model.

  ## Options

    * `:config` - Required. The configuration struct.

  """
  @spec list_analysis_types(String.t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def list_analysis_types(app_id, opts \\ []) do
    path = "api/v1/apps/#{app_id}/insight-analyses"
    Client.get(path, Helpers.get_config(opts))
  end

  @doc """
  Gets the natural language model info for an app.

  Returns model status, supported languages, and vocabulary information.
  """
  @spec get_model(String.t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def get_model(app_id, opts \\ []) do
    path = "api/v1/apps/#{app_id}/insight-analyses/model"
    Client.get(path, Helpers.get_config(opts))
  end
end
