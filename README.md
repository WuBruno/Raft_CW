# 60009 Distributed Algorithms: Raft Coursework

Author: Bruno Wu (bw1121)

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `raft_cw` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:raft_cw, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/raft_cw>.

## Testing

Run `make run` to run the system.

Comment and uncomment `SETUP` to pick the type of environment to test. `DEBUG_OPTIONS` can also also support many different messages to be released when debugged.

The `logs` directory contains all the logs from testing in the report.
