defmodule QlikElixir.Error do
  @moduledoc """
  Custom error types for QlikElixir operations.
  """

  defstruct [:type, :message, :details, :request, :response]

  @type t :: %__MODULE__{
          type: error_type(),
          message: String.t(),
          details: map() | nil,
          request: map() | nil,
          response: map() | nil
        }

  @type error_type ::
          :validation_error
          | :upload_error
          | :authentication_error
          | :configuration_error
          | :file_exists_error
          | :file_not_found
          | :file_too_large
          | :network_error
          | :unknown_error

  @doc """
  Creates a new error with the given type and message.
  """
  @spec new(error_type(), String.t(), keyword()) :: t()
  def new(type, message, opts \\ []) do
    %__MODULE__{
      type: type,
      message: message,
      details: Keyword.get(opts, :details),
      request: Keyword.get(opts, :request),
      response: Keyword.get(opts, :response)
    }
  end

  @doc """
  Creates a validation error.
  """
  @spec validation_error(String.t(), keyword()) :: t()
  def validation_error(message, opts \\ []) do
    new(:validation_error, message, opts)
  end

  @doc """
  Creates an upload error.
  """
  @spec upload_error(String.t(), keyword()) :: t()
  def upload_error(message, opts \\ []) do
    new(:upload_error, message, opts)
  end

  @doc """
  Creates an authentication error.
  """
  @spec authentication_error(String.t(), keyword()) :: t()
  def authentication_error(message, opts \\ []) do
    new(:authentication_error, message, opts)
  end

  @doc """
  Creates a configuration error.
  """
  @spec configuration_error(String.t(), keyword()) :: t()
  def configuration_error(message, opts \\ []) do
    new(:configuration_error, message, opts)
  end

  @doc """
  Creates a file exists error.
  """
  @spec file_exists_error(String.t(), keyword()) :: t()
  def file_exists_error(message, opts \\ []) do
    new(:file_exists_error, message, opts)
  end

  @doc """
  Creates a file not found error.
  """
  @spec file_not_found(String.t(), keyword()) :: t()
  def file_not_found(message, opts \\ []) do
    new(:file_not_found, message, opts)
  end

  @doc """
  Creates a file too large error.
  """
  @spec file_too_large(String.t(), keyword()) :: t()
  def file_too_large(message, opts \\ []) do
    new(:file_too_large, message, opts)
  end

  @doc """
  Creates a network error.
  """
  @spec network_error(String.t(), keyword()) :: t()
  def network_error(message, opts \\ []) do
    new(:network_error, message, opts)
  end

  @doc """
  Creates an unknown error.
  """
  @spec unknown_error(String.t(), keyword()) :: t()
  def unknown_error(message, opts \\ []) do
    new(:unknown_error, message, opts)
  end

  defimpl String.Chars do
    def to_string(%QlikElixir.Error{} = error) do
      "#{error.type}: #{error.message}"
    end
  end
end
