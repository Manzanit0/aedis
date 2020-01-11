defmodule AppSignal do
  @moduledoc """
  AppSignal integration uses the Graph API to obtain the throughput
  of every endpoint.

  The API returns an list of hourly stats, so to get the full hit count
  of a given endpoint it reduces the full list, aggregating the hourly count.
  """

  @behaviour Observer

  defstruct [:endpoint, :method, :count]

  @live_app_id System.get_env("APPSIGNAL_LIVE_APP_ID")
  @token System.get_env("APPSIGNAL_API_TOKEN")

  @doc """
  `AppSignal.hit_count/1` uses the module and the function to get the throughput for that action via
  the Graph API. It then returns a `%AppSignal{}` struct with the count of hits in the last month.

  The function expects a `%Phoenix.Route{}`.
  """
  @impl true
  def hit_count(%{endpoint: endpoint, method: method, module: module, function: function}) do
    params = [
      "timeframe=month",
      # FIXME for channels, it has to be kind=channel !!
      "kind=web",
      "fields[]=count",
      "fields[]=ex_rate",
      "action_name=#{module}-hash-#{String.replace(function, ":", "")}",
      "token=#{@token}"
    ]

    url = "https://appsignal.com/api/#{@live_app_id}/graphs.json?" <> Enum.join(params, "&")

    case HTTPoison.get!(url, recv_timeout: :infinity, timeout: :infinity) do
      %{body: body, status_code: 200} -> to_result(endpoint, method, body)
      _ -> :error
    end
  end

  def to_result(endpoint, method, body) do
    count =
      body
      |> Poison.decode!()
      |> Map.get("data")
      |> Enum.reduce(0, &reduce/2)

    # TODO this might fail if body changes in the future?
    {:ok, %__MODULE__{endpoint: endpoint, method: method, count: count}}
  end

  defp reduce(%{"count" => count}, acc), do: acc + count

  # Sometimes the endpoint isn't called in a certain timeframe, so the
  # properties don't come.
  defp reduce(_, acc), do: acc
end
