defmodule QlikElixir.REST.Users do
  @moduledoc """
  REST API client for Qlik Cloud Users.

  Provides functions to manage users including listing, creating, updating,
  and deleting users, as well as filtering and inviting users.

  ## Examples

      # List all users
      {:ok, %{"data" => users}} = Users.list(config: config)

      # Get current user
      {:ok, user} = Users.me(config: config)

      # Get user by ID
      {:ok, user} = Users.get("user-123", config: config)

      # Create a new user
      {:ok, user} = Users.create(%{name: "Alice", email: "alice@example.com"}, config: config)

      # Invite users
      {:ok, result} = Users.invite(["user1@example.com", "user2@example.com"], config: config)

  """

  alias QlikElixir.{Client, Error}
  alias QlikElixir.REST.Helpers

  @base_path "api/v1/users"

  @doc """
  Lists all users.

  ## Options

    * `:config` - Required. The configuration struct.
    * `:limit` - Maximum number of results per page.
    * `:next` - Cursor for pagination.
    * `:filter` - SCIM filter string.
    * `:sort` - Sort field and direction.

  """
  @spec list(keyword()) :: {:ok, map()} | {:error, Error.t()}
  def list(opts \\ []) do
    query = Helpers.build_query(opts, [{:filter, :filter}, {:sort, :sort}])
    path = Helpers.build_path(@base_path, query)
    Client.get(path, Helpers.get_config(opts))
  end

  @doc """
  Gets a user by ID.
  """
  @spec get(String.t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def get(user_id, opts \\ []) do
    "#{@base_path}/#{user_id}"
    |> Client.get(Helpers.get_config(opts))
    |> Helpers.normalize_get_response("User")
  end

  @doc """
  Gets the current authenticated user.
  """
  @spec me(keyword()) :: {:ok, map()} | {:error, Error.t()}
  def me(opts \\ []) do
    path = "#{@base_path}/me"
    Client.get(path, Helpers.get_config(opts))
  end

  @doc """
  Creates a new user.

  ## Parameters

    * `params` - Map with user details:
      * `:name` - Required. User display name.
      * `:email` - Required. User email address.
      * `:subject` - Identity provider subject (optional).

  """
  @spec create(map(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def create(params, opts \\ []) do
    body = Helpers.build_body(params, [:name, :email, :subject, :roles, :status])
    Client.post(@base_path, body, Helpers.get_config(opts))
  end

  @doc """
  Updates a user.

  ## Parameters

    * `user_id` - The user ID.
    * `params` - Map with fields to update.

  """
  @spec update(String.t(), map(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def update(user_id, params, opts \\ []) do
    path = "#{@base_path}/#{user_id}"
    body = Helpers.build_body(params, [:name, :email, :status, :roles])
    Client.patch(path, body, Helpers.get_config(opts))
  end

  @doc """
  Deletes a user.
  """
  @spec delete(String.t(), keyword()) :: :ok | {:error, Error.t()}
  def delete(user_id, opts \\ []) do
    "#{@base_path}/#{user_id}"
    |> Client.delete(Helpers.get_config(opts))
    |> Helpers.normalize_delete_response("User")
  end

  @doc """
  Gets the count of users.

  ## Options

    * `:filter` - SCIM filter string to count matching users.

  """
  @spec count(keyword()) :: {:ok, map()} | {:error, Error.t()}
  def count(opts \\ []) do
    query = Helpers.build_query(opts, [{:filter, :filter}])
    path = Helpers.build_path("#{@base_path}/actions/count", query)
    Client.get(path, Helpers.get_config(opts))
  end

  @doc """
  Filters users using SCIM filter syntax.

  ## Parameters

    * `filter_query` - SCIM filter string (e.g., `email eq "test@example.com"`).

  """
  @spec filter(String.t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def filter(filter_query, opts \\ []) do
    path = "#{@base_path}/actions/filter"
    body = %{"filter" => filter_query}
    Client.post(path, body, Helpers.get_config(opts))
  end

  @doc """
  Invites users by email.

  ## Parameters

    * `emails` - List of email addresses to invite.

  """
  @spec invite(list(String.t()), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def invite(emails, opts \\ []) when is_list(emails) do
    path = "#{@base_path}/actions/invite"
    body = %{"emails" => emails}
    Client.post(path, body, Helpers.get_config(opts))
  end
end
