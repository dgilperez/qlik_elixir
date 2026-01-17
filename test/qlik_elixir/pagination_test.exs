defmodule QlikElixir.PaginationTest do
  use ExUnit.Case, async: true

  alias QlikElixir.Pagination

  describe "build_query/1" do
    test "returns empty string with no options" do
      assert "" = Pagination.build_query([])
    end

    test "builds query with limit" do
      assert "limit=50" = Pagination.build_query(limit: 50)
    end

    test "builds query with limit and offset" do
      assert "limit=50&offset=100" = Pagination.build_query(limit: 50, offset: 100)
    end

    test "builds query with cursor (next)" do
      assert "limit=50&next=abc123" = Pagination.build_query(limit: 50, next: "abc123")
    end

    test "ignores nil values" do
      assert "limit=50" = Pagination.build_query(limit: 50, offset: nil, next: nil)
    end
  end

  describe "parse_response/1" do
    test "extracts pagination info from response with links" do
      response = %{
        "data" => [%{"id" => "1"}, %{"id" => "2"}],
        "links" => %{
          "next" => %{"href" => "/api/v1/items?next=token123"},
          "prev" => %{"href" => "/api/v1/items?prev=token456"}
        }
      }

      assert %{
               data: [%{"id" => "1"}, %{"id" => "2"}],
               next_cursor: "token123",
               prev_cursor: "token456",
               has_more: true
             } = Pagination.parse_response(response)
    end

    test "handles response without next link" do
      response = %{
        "data" => [%{"id" => "1"}],
        "links" => %{}
      }

      assert %{
               data: [%{"id" => "1"}],
               next_cursor: nil,
               prev_cursor: nil,
               has_more: false
             } = Pagination.parse_response(response)
    end

    test "handles response without links key" do
      response = %{"data" => [%{"id" => "1"}]}

      assert %{
               data: [%{"id" => "1"}],
               next_cursor: nil,
               prev_cursor: nil,
               has_more: false
             } = Pagination.parse_response(response)
    end

    test "handles response with total count" do
      response = %{
        "data" => [%{"id" => "1"}],
        "total" => 100
      }

      result = Pagination.parse_response(response)
      assert result.total == 100
    end
  end

  describe "extract_cursor/1" do
    test "extracts cursor from URL with next param" do
      url = "/api/v1/items?limit=50&next=abc123"
      assert "abc123" = Pagination.extract_cursor(url, "next")
    end

    test "returns nil when cursor not found" do
      url = "/api/v1/items?limit=50"
      assert nil == Pagination.extract_cursor(url, "next")
    end

    test "returns nil for nil URL" do
      assert nil == Pagination.extract_cursor(nil, "next")
    end
  end
end
