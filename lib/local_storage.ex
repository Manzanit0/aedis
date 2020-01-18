defmodule LocalStorage do
  @moduledoc """
  Helper module to write to/read from ~/.aedis config file. All variables are
  stored as `name=value`, and when read, will return the first ocurrence.
  """

  @doc """
  Saves name/value tuple to local storage and creates the file if it
  doesn't exist.
  """
  def save!(name, value) do
    file =
      System.user_home()
      |> Path.join(".aedis")
      |> File.open!([:append])

    IO.binwrite(file, "#{name}=#{value}\n")
    File.close(file)
  end

  def read!(name) do
    case read(name) do
      {:error, reason} -> raise "Error reading #{name} - #{reason}"
      token -> token
    end
  end

  @doc """
  Reads the variable with name `name`.

  Can return any of the errors from `File.read/1` upon trying to read
  the config file, as well as:
    - `:novar` - The config file exists and has been read successfuly, but the
  config variable doesn't exist.
  """
  def read(name) do
    System.user_home()
    |> Path.join(".aedis")
    |> File.read()
    |> find_config_variable(name)
  end

  defp find_config_variable({:error, reason}, _), do: {:error, reason}

  defp find_config_variable({:ok, content}, name) do
    case find_first_occurrence(content, name) do
      nil -> {:error, :novar}
      variable -> parse_value(variable)
    end
  end

  defp find_first_occurrence(content, name) do
    content
    |> String.split("\n")
    |> Enum.filter(fn x -> String.contains?(x, name) end)
    |> List.first()
  end

  defp parse_value(variable) do
    variable
    |> String.split("=")
    |> Enum.at(1)
  end

@doc "Deletes local storage file `~/.aedis`"
  def nuke do
    System.user_home()
    |> Path.join(".aedis")
    |> File.rm()
  end
end
