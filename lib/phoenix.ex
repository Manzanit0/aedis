defmodule Phoenix do
  @moduledoc """
  Phoenix module simply parses the content from `phx.routes`. It
  serves as a record of all existing HTTP endpoints in the application.
  """

  # TODO Extracting the File.cd and the System.cmd, should be testable
  def routes(path, router \\ "") do
    with :ok <- File.cd(path) do
      System.cmd("mix", ["deps.get"])
      System.cmd("mix", ["compile"])

      System.cmd("mix", ["phx.routes", router])
      |> elem(0)
      |> String.split("\n")
      |> Enum.map(&trim_leading_spaces/1)
      |> Enum.map(&split_by_spaces/1)
      |> Enum.map(&prune_empty_strings/1)
      |> Enum.map(&parse_route/1)
      |> Enum.reject(&is_nil/1)
    else
      {:error, :enoent} -> "Error locating directory"
    end
  end

  defp split_by_spaces(row), do: String.split(row, " ")

  defp trim_leading_spaces(row), do: String.replace_leading(row, " ", "")

  defp prune_empty_strings(row), do: Enum.reject(row, fn x -> x == "" end)

  defp parse_route([_pipeline | [method | [endpoint | [module | [function | []]]]]]),
    do: Phoenix.Route.new(endpoint, method, module, function)

  defp parse_route([method | [endpoint | [module | [function | []]]]]),
    do: Phoenix.Route.new(endpoint, method, module, function)

  defp parse_route([]), do: nil
  defp parse_route(_), do: nil
end

defmodule Phoenix.Route do
  defstruct [:endpoint, :method, :module, :function]

  def new(endpoint, method, module, function) do
    %Phoenix.Route{
      endpoint: endpoint,
      method: method,
      module: module,
      function: function
    }
  end
end
