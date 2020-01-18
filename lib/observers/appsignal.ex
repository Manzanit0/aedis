defmodule AppSignal do
  @moduledoc """
  AppSignal integration uses the Graph API to obtain the throughput
  of every endpoint.

  The API returns an list of hourly stats, so to get the full hit count
  of a given endpoint it reduces the full list, aggregating the hourly count.
  """

  @behaviour Observer

  defstruct [:endpoint, :method, :count]

  def test_connection do
    url = "https://appsignal.com/api/#{get_app_id!()}/markers.json?token=#{get_api_token!()}"
    case HTTPoison.get!(url, recv_timeout: :infinity, timeout: :infinity) do
      %{status_code: 200} -> :ok
      %{status_code: 401} -> {:error, :unauthorized}
      %{status_code: 404} -> {:error, :app_not_found}
      _ -> {:error, :unknown}
    end
  end

  def test_connection! do
    case test_connection() do
      :ok -> :ok
      {:error, reason} -> raise "Connection to AppSignal failed - #{reason}"
    end
  end

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
      "token=#{get_api_token!()}"
    ]

    url = "https://appsignal.com/api/#{get_app_id!()}/graphs.json?" <> Enum.join(params, "&")

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

  def get_api_token! do
    LocalStorage.read!("APPSIGNAL_API_TOKEN")
  end

  def save_api_token!(token) do
    LocalStorage.save!("APPSIGNAL_API_TOKEN", token)
  end

  def get_app_id! do
    LocalStorage.read!("APPSIGNAL_LIVE_APP_ID")
  end

  def save_app_id!(app_id) do
    LocalStorage.save!("APPSIGNAL_LIVE_APP_ID", app_id)
  end
end
