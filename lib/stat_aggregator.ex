defmodule Result do
  defstruct [:endpoint, :method, :graylog_count, :appsignal_count]
end

defmodule StatAggregator do
  @moduledoc """
  This module's main purpose is to fetch stats from multiple providers, like
  Graylog and AppSignal, and aggregate them by endpoint.

  To fetch the statistics it makes use of the services' public APIs and encapsulates
  each HTTP call in a Task, to parallelise as much as possible those side-effects.

  The one and only entry point to the module is `get_aggregated_stats/1` which accepts
  a list of `%Phoenix.Route{}`, and will return a list of `%Result{}` with all the data
  populated.
  """

  @appsignal Application.fetch_env!(:aedis, :appsignal_module)
  @graylog Application.fetch_env!(:aedis, :graylog_module)

  def get_aggregated_stats(routes) when is_list(routes) do
    # FIXME - failed endpoints are not reported
    routes
    |> get_stats()
    |> Enum.filter(&successful?/1)
    |> Enum.map(fn {:ok, result} -> result end)
    |> aggregate_by_endpoint()
    |> sort_by_count()
  end

  defp get_stats(routes, tasks \\ [])

  defp get_stats([head | tail], tasks) do
    t1 = Task.async(fn -> @appsignal.hit_count(head) end)
    t2 = Task.async(fn -> @graylog.hit_count(head) end)
    get_stats(tail, [t1 | [t2 | tasks]])
  end

  defp get_stats([], tasks) do
    Enum.map(tasks, fn task -> Task.await(task, 50_000) end)
  end

  defp successful?({:ok, _}), do: true
  defp successful?(:error), do: false

  defp aggregate_by_endpoint(mixed_results, aggregated_results \\ %{})

  defp aggregate_by_endpoint([], aggregated_results) do
    Map.values(aggregated_results)
  end

  defp aggregate_by_endpoint([head | tail], aggregated_results) do
    key = head.endpoint <> head.method
    value = Map.get(aggregated_results, key)
    result = aggregate(head, value)
    aggregate_by_endpoint(tail, Map.put(aggregated_results, key, result))
  end

  defp aggregate(%Graylog{count: c}, %Result{} = r), do: %Result{r | graylog_count: c}

  defp aggregate(%Graylog{endpoint: e, method: m, count: c}, nil),
    do: %Result{endpoint: e, method: m, graylog_count: c}

  defp aggregate(%AppSignal{count: c}, %Result{} = r), do: %Result{r | appsignal_count: c}

  defp aggregate(%AppSignal{endpoint: e, method: m, count: c}, nil),
    do: %Result{endpoint: e, method: m, appsignal_count: c}

  defp sort_by_count([]), do: []

  defp sort_by_count(results) do
    Enum.sort_by(results, fn %Result{appsignal_count: count} -> count end, &>=/2)
  end
end
