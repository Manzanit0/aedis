defmodule Graylog do
  @moduledoc """
  Graylog integration counts the amount of messages which contain the endpoint
  in its content, hence no extremely accurate, but good enough to detect unused
  endpoints.

    ## Authenticating with Graylog

  To create a Graylog Access Token check their
  [documentation](https://docs.graylog.org/en/3.1/pages/configuration/rest_api.html#creating-and-using-access-token).
  In order to be able to invoke `hit_count/1` successfully, the session token
  must be stored as an environment variable in `GRAYLOG_AUTH_TOKEN`.
  """

  @behaviour Observer

  defstruct [:endpoint, :method, :count]

  @url "https://graylog.rekki.com/api/search/universal/relative"

  def new(endpoint, method, count),
    do: %__MODULE__{endpoint: endpoint, method: method, count: count}

  @impl true
  def hit_count(%{endpoint: endpoint, method: method}) do
    url = @url <> get_query_params(endpoint, method)

    case HTTPoison.get!(url, get_headers!(), recv_timeout: :infinity, timeout: :infinity) do
      %{body: body, status_code: 200} -> to_result(endpoint, method, body)
      _ -> :error
    end
  end

  def get_query_params(endpoint, method) do
    sanitised_endpoint = sanitise_with_wildcards(endpoint)

    params = [
      "query=message:\"#{sanitised_endpoint}\" AND message: \"#{method}\"",
      "range=2592000",
      "limit=150",
      "sort=timestamp:desc"
    ]

    params
    |> Enum.join("&")
    |> String.replace_prefix("", "?")
    |> URI.encode()
  end

  def get_headers! do
    [
      {"Accept", "application/json"},
      {"authorization", build_auth_header!()}
    ]
  end

  def to_result(endpoint, method, body) do
    count = extract_count(body)
    result = new(endpoint, method, count)
    {:ok, result}
  end

  def sanitise_with_wildcards(endpoint) do
    endpoint
    |> String.split("/")
    |> Enum.map(&replace_term_for_wildcard/1)
    |> Enum.join("/")
  end

  defp replace_term_for_wildcard(term) do
    if String.starts_with?(term, ":"), do: "*", else: term
  end

  def build_auth_header!() do
    user = get_auth_token!()
    pass = "token"
    "Basic #{Base.encode64(user <> ":" <> pass)}"
  end

  defp extract_count(body) do
    body
    |> Poison.decode!()
    |> Map.get("total_results")
  end

  def get_auth_token! do
    LocalStorage.read!("GRAYLOG_AUTH_TOKEN")
  end

  def save_auth_token!(token) do
    LocalStorage.save!("GRAYLOG_AUTH_TOKEN", token)
  end
end
