defmodule QlikElixir.ErrorTest do
  use ExUnit.Case
  doctest QlikElixir.Error

  alias QlikElixir.Error

  describe "new/3" do
    test "creates an error with all fields" do
      error =
        Error.new(:upload_error, "Upload failed",
          details: %{reason: "timeout"},
          request: %{url: "http://example.com"},
          response: %{status: 500}
        )

      assert error.type == :upload_error
      assert error.message == "Upload failed"
      assert error.details == %{reason: "timeout"}
      assert error.request == %{url: "http://example.com"}
      assert error.response == %{status: 500}
    end

    test "creates an error with minimal fields" do
      error = Error.new(:validation_error, "Invalid input")

      assert error.type == :validation_error
      assert error.message == "Invalid input"
      assert error.details == nil
      assert error.request == nil
      assert error.response == nil
    end
  end

  describe "error constructors" do
    test "validation_error/2" do
      error = Error.validation_error("Invalid file")
      assert error.type == :validation_error
      assert error.message == "Invalid file"
    end

    test "upload_error/2" do
      error = Error.upload_error("Upload failed", response: %{status: 409})
      assert error.type == :upload_error
      assert error.message == "Upload failed"
      assert error.response == %{status: 409}
    end

    test "authentication_error/2" do
      error = Error.authentication_error("Invalid API key")
      assert error.type == :authentication_error
      assert error.message == "Invalid API key"
    end

    test "configuration_error/2" do
      error = Error.configuration_error("Missing API key")
      assert error.type == :configuration_error
      assert error.message == "Missing API key"
    end

    test "file_exists_error/2" do
      error = Error.file_exists_error("File already exists")
      assert error.type == :file_exists_error
      assert error.message == "File already exists"
    end

    test "file_not_found/2" do
      error = Error.file_not_found("File not found")
      assert error.type == :file_not_found
      assert error.message == "File not found"
    end

    test "file_too_large/2" do
      error = Error.file_too_large("File exceeds size limit")
      assert error.type == :file_too_large
      assert error.message == "File exceeds size limit"
    end

    test "network_error/2" do
      error = Error.network_error("Connection timeout")
      assert error.type == :network_error
      assert error.message == "Connection timeout"
    end

    test "unknown_error/2" do
      error = Error.unknown_error("Something went wrong")
      assert error.type == :unknown_error
      assert error.message == "Something went wrong"
    end
  end

  describe "String.Chars implementation" do
    test "converts error to string" do
      error = Error.new(:upload_error, "Upload failed")
      assert to_string(error) == "upload_error: Upload failed"
    end
  end
end
