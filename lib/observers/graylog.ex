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

  alias Poison.ParseError

  @behaviour Observer

  defstruct [:endpoint, :method, :count]

  @url "https://graylog.rekki.com/api/search/universal/relative"
  @test_url "https://graylog.rekki.com/api/cluster"

  def new(endpoint, method, count),
    do: %__MODULE__{endpoint: endpoint, method: method, count: count}

  def test_connection do
    with {:ok, token} <- get_auth_token() do
      headers = build_headers(token)

      case HTTPoison.get!(@test_url, headers, recv_timeout: :infinity, timeout: :infinity) do
        %{status_code: 200} -> :ok
        %{status_code: 401} -> {:error, :unauthorized}
        %{status_code: 503} -> {:error, :service_unavailable}
        _ -> {:error, :unknown}
      end
    else
      error -> error
    end
  end

  @impl true
  def hit_count(%{endpoint: endpoint, method: method}) do
    with {:ok, token} <- get_auth_token() do
      url = @url <> build_query_params(endpoint, method)
      headers = build_headers(token)

      case HTTPoison.get!(url, headers, recv_timeout: :infinity, timeout: :infinity) do
        %{body: body, status_code: 200} -> to_result(endpoint, method, body)
        _ -> {:error, :httperror}
      end
    else
      error -> error
    end
  end

  def build_query_params(endpoint, method) do
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

  def build_headers(auth_token) do
    [
      {"Accept", "application/json"},
      {"authorization", "Basic #{Base.encode64(auth_token <> ":" <> "token")}"}
    ]
  end

  def to_result(endpoint, method, body) do
    case extract_count(body) do
      {:ok, count} -> {:ok, new(endpoint, method, count)}
      error -> error
    end
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

  defp extract_count(body) do
    case Poison.decode(body) do
      {:ok, decoded} -> {:ok, Map.get(decoded, "total_results")}
      {:error, err} -> {:error, ParseError.message(err)}
    end
  end

  def get_auth_token, do: LocalStorage.read("GRAYLOG_AUTH_TOKEN")

  def save_auth_token!(token), do: LocalStorage.save!("GRAYLOG_AUTH_TOKEN", token)
end
