defmodule Aedis do
  @moduledoc """
  Dark Keeper Aedis is a keeper located at the World Soul in Antorus, the Burning Throne.

  > Your presence is an infestation. Infestations must be purged!

  ## Purpose

  Aedis is a lightweight commandline application which finds unused endpoints via different
  providers like Graylog or AppSignal.

  ## Usage

  To compile the project, run:

  ```
  git clone https://github.com/Manzanit0/aedis
  cd aedis
  mix deps.get
  mix escript.build
  ```

  And then just run `aedis` with the following parameters:

  Example:

  ```
  ./aedis --path=/home/manzanit0/Work/backend/ --router=Chat.Web.Router
  ```
  """

  alias Aedis.LocalStorage
  alias Aedis.Phoenix
  alias Aedis.StatAggregator
  alias Aedis.Services.Graylog
  alias Aedis.Services.AppSignal

  def main(args) do
    try do
      args
      |> parse_params()
      |> execute()
    rescue
      e in RuntimeError -> IO.puts(e.message)
    end
  end

  defp parse_params(args) do
    # TODO parse invalid options
    args
    |> OptionParser.parse(
      strict: [
        init: :boolean,
        path: :string,
        router: :string,
        help: :boolean,
        graylog: :boolean,
        appsignal: :boolean
      ]
    )
    |> elem(0)
  end

  def execute(help: true) do
    IO.puts("""
    usage: aedis [--help] [--init] [--path=<path>] [--router=<module>]

    Make sure you run aedis with --init before attempting to inspect your API.

    The most common use case is:
      $ aedis --path=/home/manzanit0/repositories/my_app --router=MyApp.Web.Router
    """)
  end

  def execute(init: true) do
    LocalStorage.nuke()

    IO.gets("Please provide you Graylog authentication token:")
    |> String.trim()
    |> String.replace("\n", "")
    |> Graylog.save_auth_token!()

    IO.gets("Please provide you AppSignal API token:")
    |> String.trim()
    |> String.replace("\n", "")
    |> AppSignal.save_api_token!()

    IO.gets("Please provide you AppSignal application ID:")
    |> String.trim()
    |> String.replace("\n", "")
    |> AppSignal.save_app_id!()

    IO.puts("Fantastic! You can now start using Aedis to inspect your API!")
  end

  def execute(opts) do
    router = Keyword.get(opts, :router, "")
    path = Keyword.get(opts, :path, File.cwd!())

    services =
      []
      |> append_if_true(Keyword.get(opts, :graylog, false), Graylog)
      |> append_if_true(Keyword.get(opts, :appsignal, false), AppSignal)
      |> Enum.map(&test_connection!/1)

    IO.puts(":: Starting to fetch and aggregate data (this can take long) ::")

    Phoenix.routes(path, router)
    |> StatAggregator.get_aggregated_stats(services)
    |> Scribe.print(data: [:method, :endpoint, :graylog_count, :appsignal_count])
  end

  defp append_if_true(list, true, item), do: list ++ [item]
  defp append_if_true(list, _, _), do: list

  defp prettify_error(error, service) do
    case error do
      {:error, :enoent} ->
        "!! Can't find configuration file. To solve, run $ aedis --init"

      {:error, :enomem} ->
        "!! Error reading config - not enough memory. This is weird..."

      {:error, :novar} ->
        "!! Missing configuration. To solve, run $ aedis --init"

      {:error, error} ->
        "!! Error connecting to #{service} -  #{error}"
    end
  end

  defp test_connection!(module) do
    case module.test_connection() do
      :ok -> module
      err -> raise prettify_error(err, module)
    end
  end
end
