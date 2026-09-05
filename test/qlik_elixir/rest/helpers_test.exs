defmodule QlikElixir.REST.HelpersTest do
  use ExUnit.Case, async: true

  alias QlikElixir.REST.Helpers

  doctest QlikElixir.REST.Helpers

  describe "build_query/2" do
    test "gives cursor pagination for free" do
      assert Helpers.build_query([limit: 10, next: "abc"], []) == "limit=10&next=abc"
    end

    test "maps option keys to API parameter names" do
      assert Helpers.build_query([space_id: "sp-1"], [{:spaceId, :space_id}]) == "spaceId=sp-1"
    end

    test "drops options that were not given" do
      assert Helpers.build_query([], [{:spaceId, :space_id}]) == ""
    end

    test "orders base parameters before the mapped ones" do
      assert Helpers.build_query([name: "x", limit: 5], [{:name, :name}]) == "limit=5&name=x"
    end
  end

  describe "build_query/3" do
    test "replaces the base parameters for endpoints that page differently" do
      query = Helpers.build_query([limit: 20, skip: 40], [{:skip, :skip}], [{:limit, :limit}])

      assert query == "limit=20&skip=40"
    end

    test "ignores a cursor the endpoint does not support" do
      query = Helpers.build_query([next: "abc", skip: 40], [{:skip, :skip}], [{:limit, :limit}])

      assert query == "skip=40"
    end
  end

  describe "build_query list values" do
    test "comma-joins a repeatable parameter" do
      assert Helpers.build_query([sort: ["+name", "-createdAt"]], [{:sort, :sort}]) ==
               "sort=%2Bname%2C-createdAt"
    end

    test "leaves a scalar untouched" do
      assert Helpers.build_query([sort: "+name"], [{:sort, :sort}]) == "sort=%2Bname"
    end
  end

  describe "join_param/1" do
    test "joins lists, passes scalars and nil through" do
      assert Helpers.join_param(["a", "b"]) == "a,b"
      assert Helpers.join_param("a") == "a"
      assert Helpers.join_param(nil) == nil
      assert Helpers.join_param([]) == ""
    end
  end

  describe "add_param/3" do
    test "keeps the accumulator when the value is nil" do
      assert Helpers.add_param([limit: 10], :name, nil) == [limit: 10]
    end

    test "appends a present value" do
      assert Helpers.add_param([], :limit, 10) == [limit: 10]
    end

    test "keeps false, which is a legitimate query value" do
      assert Helpers.add_param([], :enabled, false) == [enabled: false]
    end
  end

  describe "build_body/2" do
    test "accepts atom keys and string keys alike" do
      assert Helpers.build_body(%{name: "a"}, [:name]) == %{"name" => "a"}
      assert Helpers.build_body(%{"name" => "a"}, [:name]) == %{"name" => "a"}
    end

    test "renames fields through tuple specs" do
      assert Helpers.build_body(%{space_id: "sp-1"}, [{"spaceId", :space_id}]) == %{"spaceId" => "sp-1"}
    end

    test "omits absent fields rather than sending nulls" do
      assert Helpers.build_body(%{name: "a", description: nil}, [:name, :description]) == %{"name" => "a"}
    end
  end

  describe "build_path/2" do
    test "appends a query string only when there is one" do
      assert Helpers.build_path("api/v1/apps", "limit=10") == "api/v1/apps?limit=10"
      assert Helpers.build_path("api/v1/apps", "") == "api/v1/apps"
    end
  end
end
