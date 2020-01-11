defmodule GraylogTest do
  use ExUnit.Case

  alias Graylog

  @moduletag :capture_log

  doctest Graylog

  test "module exists" do
    assert is_list(Graylog.module_info())
  end

  describe "sanitise with wildcards" do
    test "anything starting with colon with underscores" do
      assert "/api/chat/*/user/*" ==
               Graylog.sanitise_with_wildcards("/api/chat/:id/user/:user_id")
    end

    test "anything starting with colon with dashes" do
      assert "/api/chat/*/user/*" ==
               Graylog.sanitise_with_wildcards("/api/chat/:id-some/user/:user_id")
    end
  end

  describe "parses API response" do
    test "valid response extracts count" do
      body = Poison.encode!(%{total_results: 4567, other: "qwerty"})
      assert {:ok, %Graylog{count: 4567}} = Graylog.to_result("endpoint", "method", body)
    end

    test "invalid response results to nil count" do
      body = Poison.encode!(%{nothing: 4567, other: "qwerty"})
      assert {:ok, %Graylog{count: nil}} = Graylog.to_result("endpoint", "method", body)
    end
  end

  describe "build auth header" do
    @tag :skip
    test "explodes upon missing auth token in env variables" do
      assert "Can't find GRAYLOG_AUTH_TOKEN" == catch_error(Graylog.build_auth_header!())
    end

    test "creates a BASIC auth header" do
      assert Graylog.build_auth_header!() =~ "Basic "
    end
  end
end
