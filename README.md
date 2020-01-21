# Aedis

Dark Keeper Aedis is a keeper located at the World Soul in Antorus, the Burning Throne.

> Your presence is an infestation. Infestations must be purged!

## Purpose

Aedis is a lightweight commandline application which finds unused endpoints in
Phoenix applications by requesting usage data to third-party services like
Graylog or AppSignal.

The results look like below:

```
+-----------------------------+--------------------------------------------------------------------------------+------------------+--------------------+
| :method                     | :endpoint                                                                      | :graylog_count   | :appsignal_count   |
+-----------------------------+--------------------------------------------------------------------------------+------------------+--------------------+
| "GET"                       | "/api/chats"                                                                   | 38029            | 345345             |
| "PUT"                       | "/api/chats"                                                                   | 31892            | 310098             |
| "POST"                      | "/api/chats/:id"                                                               | 23987            | 21828              |
| "GET"                       | "/api/chats/:id"                                                               | 15606            | 19808              |
| "POST"                      | "/api/chats/:id/orders"                                                        | 11878            | 11878              |
| "POST"                      | "/api/channel_actions/:channel"                                                | 421              | 432                |
| "POST"                      | "/api/channel_actions/:channel/:id"                                            | 219              | 289                |
| ...                         | ...                                                                            | ...              | ...                |
+-----------------------------+--------------------------------------------------------------------------------+------------------+--------------------+

```

## Usage

Clone and compile the application:

```
git clone https://github.com/Manzanit0/aedis
cd aedis
mix deps.get
mix escript.build
```

Init necessary configuration (this will save all sensitive data under `~/.aedis`):

```shell script
./aedis --init
```

Inspect your Phoenix project:

```shell script
./aedis --path=/home/javiergarciamanzano/Work/rekki-backend/ --router=Chat.Web.Router
```

Where `path` expects the path of a Phoenix project and `router` the name of the Phoenix router.

## TODO

- Implement something similar for channel topics

## Benchmarks for fun

While the development of the application I benchmarked some things, to get a rough idea of performance
differences and I found the following to be quite interesting. Below for those of you interested :-)

```elixir
  def sync(path, router) do
    for {endpoint, method, _module, _func} <- Phoenix.routes(path, router) do
      Graylog.hit_count(endpoint, method)
    end
  end

  def async(path, router) do
    Phoenix.routes(path, router)
    |> Enum.map(fn {endpoint, method, _module, _func} -> Task.async(fn -> Graylog.hit_count(endpoint, method) end) end)
    |> Enum.map(&(Task.await &1, 50_000))
  end
```

Benchmarks with Benchee:

```
Name            ips        average  deviation         median         99th %
async        0.0403        24.82 s     ±0.00%        24.82 s        24.82 s
sync         0.0177        56.53 s     ±0.00%        56.53 s        56.53 s

Comparison: 
async        0.0403
sync         0.0177 - 2.28x slower +31.71 s

Memory usage statistics:

Name     Memory usage
async         0.82 MB
sync        335.94 MB - 407.52x memory usage +335.11 MB
```
