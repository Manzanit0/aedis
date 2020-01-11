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
    |> OptionParser.parse(strict: [path: :string, router: :string, help: :boolean])
    |> elem(0)
  end

  def execute(help: true) do
    IO.puts("""
    usage: aedis [--help] [--path=<path>] [--router=<module>]
    The most common use case is:
      $ aedis --path=/home/manzanit0/repositories/my_app --router=MyApp.Web.Router
    """)
  end

  def execute(path: path, router: router) do
    Phoenix.routes(path, router)
    |> StatAggregator.get_aggregated_stats()
    |> Scribe.print(data: [:method, :endpoint, :graylog_count, :appsignal_count])
  end

  def execute(path: path) do
    execute(path: path, router: "")
  end

  def execute(_) do
    IO.puts("That is not a valid aedis command. See 'aedis --help'.")
  end
end
