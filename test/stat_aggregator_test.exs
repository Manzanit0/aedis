defmodule StatAggregatorTest do
  use ExUnit.Case

  import Mox

  alias Aedis.Phoenix
  alias Aedis.StatAggregator
  alias Aedis.StatAggregator.Result
  alias Aedis.Services.Graylog
  alias Aedis.Services.AppSignal

  @services [
    Application.fetch_env!(:aedis, :appsignal_module),
    Application.fetch_env!(:aedis, :graylog_module)
  ]

  test "gets aggregated stats, discarding errors" do
    GraylogMock
    |> expect(:hit_count, fn %{endpoint: e, method: m} ->
      {:ok, %Graylog{endpoint: e, method: m, count: 2}}
    end)
    |> expect(:hit_count, fn _ -> :error end)

    AppSignalMock
    |> expect(:hit_count, fn _ -> :error end)
    |> expect(:hit_count, fn %{endpoint: e, method: m} ->
      {:ok, %AppSignal{endpoint: e, method: m, count: 2}}
    end)

    routes = [
      Phoenix.Route.new("/api/v2/chat/:id", "GET", "ChatController", ":show"),
      Phoenix.Route.new("/api/v2/chat/:id", "POST", "ChatController", ":update")
    ]

    [endpoint_1, endpoint_2] = StatAggregator.get_aggregated_stats(routes, @services)

    assert %Result{
             endpoint: "/api/v2/chat/:id",
             method: "GET",
             appsignal_count: nil,
             graylog_count: 2
           } = endpoint_1

    assert %Result{
             endpoint: "/api/v2/chat/:id",
             method: "POST",
             appsignal_count: 2,
             graylog_count: nil
           } = endpoint_2
  end

  test "results are sorted by AppSignal count" do
    GraylogMock
    |> expect(:hit_count, fn _ -> :error end)
    |> expect(:hit_count, fn _ -> :error end)
    |> expect(:hit_count, fn _ -> :error end)
    |> expect(:hit_count, fn _ -> :error end)

    AppSignalMock
    |> expect(:hit_count, fn %{endpoint: e, method: m} ->
      {:ok, %AppSignal{endpoint: e, method: m, count: 3}}
    end)
    |> expect(:hit_count, fn %{endpoint: e, method: m} ->
      {:ok, %AppSignal{endpoint: e, method: m, count: 1}}
    end)
    |> expect(:hit_count, fn %{endpoint: e, method: m} ->
      {:ok, %AppSignal{endpoint: e, method: m, count: 5}}
    end)
    |> expect(:hit_count, fn %{endpoint: e, method: m} ->
      {:ok, %AppSignal{endpoint: e, method: m, count: 2}}
    end)

    routes = [
      Phoenix.Route.new("/api/v2/chat/:id", "GET", "ChatController", ":show"),
      Phoenix.Route.new("/api/v2/chat/:id", "POST", "ChatController", ":update"),
      Phoenix.Route.new("/api/v2/order", "GET", "OrderController", ":get_all"),
      Phoenix.Route.new("/api/v2/order/:id", "GET", "OrderController", ":get")
    ]

    [endpoint_1, endpoint_2, endpoint_3, endpoint_4] =
      StatAggregator.get_aggregated_stats(routes, @services)

    assert %Result{appsignal_count: 5} = endpoint_1
    assert %Result{appsignal_count: 3} = endpoint_2
    assert %Result{appsignal_count: 2} = endpoint_3
    assert %Result{appsignal_count: 1} = endpoint_4
  end
end
