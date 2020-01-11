defmodule Observer do
  @moduledoc """
  This is a behaviour to model all third-party services which fetch
  stats for given services, i.e. Graylog, AppSignal, etc.
  """

  @callback hit_count(struct()) :: {:ok, struct()} | :error
end
