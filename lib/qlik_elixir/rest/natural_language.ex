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
  Asks a natural language question about an app's data.

  ## Parameters

    * `app_id` - The app ID to query.
    * `question` - The natural language question.

  ## Options

    * `:config` - Required. The configuration struct.
    * `:conversation_id` - Continue an existing conversation.
    * `:lang` - Language code for the question (e.g., "en", "es").

  ## Returns

  A response containing:
    * `conversationId` - ID for continuing the conversation.
    * `responses` - List of response objects (narrative, chart, etc.).
    * `followUps` - Suggested follow-up questions.

  """
  @spec ask(String.t(), String.t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def ask(app_id, question, opts \\ []) do
    path = "api/v1/apps/#{app_id}/insight-analyses/actions/ask"

    body =
      %{"text" => question}
      |> Helpers.put_if_present("conversationId", Keyword.get(opts, :conversation_id))
      |> Helpers.put_if_present("lang", Keyword.get(opts, :lang))

    Client.post(path, body, Helpers.get_config(opts))
  end

  @doc """
  Gets analysis recommendations for an app.

  Returns suggested analyses based on the app's data model.

  ## Options

    * `:config` - Required. The configuration struct.
    * `:fields` - Filter recommendations by specific fields.
    * `:target` - Target type for recommendations (e.g., "analysis").

  """
  @spec get_recommendations(String.t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def get_recommendations(app_id, opts \\ []) do
    query =
      Helpers.build_query(opts, [
        {:fields, :fields},
        {:target, :target}
      ])

    path = Helpers.build_path("api/v1/apps/#{app_id}/insight-analyses/recommendations", query)
    Client.get(path, Helpers.get_config(opts))
  end

  @doc """
  Gets available fields for natural language analysis.

  Returns fields from the app's data model that can be used in NL queries.
  """
  @spec get_fields(String.t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def get_fields(app_id, opts \\ []) do
    path = "api/v1/apps/#{app_id}/insight-analyses/fields"
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
