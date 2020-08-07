defmodule AppSignalTest do
  use ExUnit.Case

  alias Aedis.Services.AppSignal

  @moduletag :capture_log

  doctest AppSignal

  test "module exists" do
    assert is_list(AppSignal.module_info())
  end

  describe "extract count from API response" do
    test "count is 0 when no stats are included" do
      response = %{
        data: [
          %{timestamp: "1111"},
          %{timestamp: "2222"},
          %{timestamp: "3333"}
        ]
      }

      body = Poison.encode!(response)
      assert {:ok, %AppSignal{count: 0}} = AppSignal.to_result("endpoint", "method", body)
    end

    test "count is the sum of all hourly stats" do
      response = %{
        data: [
          %{timestamp: "1111", count: 1},
          %{timestamp: "2222", count: 2},
          %{timestamp: "3333"}
        ]
      }

      body = Poison.encode!(response)
      assert {:ok, %AppSignal{count: 3}} = AppSignal.to_result("endpoint", "method", body)
    end
  end
end
