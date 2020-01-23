import Config

# TODO added this due to getting `{:error, %HTTPoison.Error{id: nil, reason: :checkout_timeout}}`
# however, this should be worked around by pooling the requests instead of parallelising all of them.
config :hackney, use_default_pool: false

import_config "#{Mix.env()}.exs"
