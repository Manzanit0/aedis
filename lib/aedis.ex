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

  def main(args) do
    args
    |> parse_params()
    |> execute()
  end

  defp parse_params(args) do
    args
    |> OptionParser.parse(
      strict: [init: :boolean, path: :string, router: :string, help: :boolean]
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

  def execute(path: path, router: router) do
    with {:gr, :ok} <- {:gr, Graylog.test_connection()},
         {:as, :ok} <- {:as, AppSignal.test_connection()} do
      IO.puts(":: Starting to fetch and aggregate data (this can take long) ::")

      Phoenix.routes(path, router)
      |> StatAggregator.get_aggregated_stats()
      |> Scribe.print(data: [:method, :endpoint, :graylog_count, :appsignal_count])
    else
      {_, {:error, :enoent}} ->
        IO.puts("!! Can't find configuration file. To solve, run $ aedis --init")

      {_, {:error, :enomem}} ->
        IO.puts("!! Error reading config - not enough memory. This is weird...")

      {_, {:error, :novar}} ->
        IO.puts("!! Missing configuration. To solve, run $ aedis --init")

      {:gr, {:error, error}} ->
        IO.puts("!! Error connecting to Graylog -  #{error}")

      {:as, {:error, error}} ->
        IO.puts("!! Error connecting to AppSignal - #{error}")
    end
  end

  def execute(path: path) do
    execute(path: path, router: "")
  end

  def execute(_) do
    IO.puts("That is not a valid aedis command. See 'aedis --help'.")
  end
end
