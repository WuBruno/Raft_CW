# distributed algorithms, n.dulay, 8 feb 2022
# raft, configuration parameters v2

defmodule Configuration do
  # _________________________________________________________ node_init()
  def node_init() do
    # get node arguments and spawn a process to exit node after max_time
    config = %{
      node_suffix: Enum.at(System.argv(), 0),
      raft_timelimit: String.to_integer(Enum.at(System.argv(), 1)),
      debug_level: String.to_integer(Enum.at(System.argv(), 2)),
      debug_options: "#{Enum.at(System.argv(), 3)}",
      n_servers: String.to_integer(Enum.at(System.argv(), 4)),
      n_clients: String.to_integer(Enum.at(System.argv(), 5)),
      setup: :"#{Enum.at(System.argv(), 6)}",
      start_function: :"#{Enum.at(System.argv(), 7)}"
    }

    if config.n_servers < 3 do
      Helper.node_halt("Raft is unlikely to work with fewer than 3 servers")
    end

    spawn(Helper, :node_exit_after, [config.raft_timelimit])

    config |> Map.merge(Configuration.params(config.setup))
  end

  # node_init

  # _________________________________________________________ node_info()
  def node_info(config, node_type, node_num \\ "") do
    Map.merge(
      config,
      %{
        node_type: node_type,
        node_num: node_num,
        node_name: "#{node_type}#{node_num}",
        node_location: Helper.node_string(),
        # for ordering output lines
        line_num: 0
      }
    )
  end

  # node_info

  # _________________________________________________________ params :default ()
  def params(:default) do
    %{
      # account numbers 1 .. n_accounts
      n_accounts: 100,
      # max amount moved between accounts in a single transaction
      max_amount: 1_000,
      # clients stops sending requests after this time(ms)
      client_timelimit: 60_000,
      # maximum no of requests each client will attempt
      max_client_requests: 1,
      # interval(ms) between client requests
      client_request_interval: 5,
      # timeout(ms) for the reply to a client request
      client_reply_timeout: 500,
      # timeout(ms) for election, set randomly in range
      election_timeout_range: 100..200,
      # timeout(ms) for the reply to a append_entries request
      append_entries_timeout: 10,
      # interval(ms) between monitor summaries
      monitor_interval: 500,
      # server_num => crash_after_time (ms), ..
      crash_servers: %{
        3 => 3_000,
        4 => 5_000
      }
    }
  end

  # params :default

  # >>>>>>>>>>>  add you setups for running experiments

  # _________________________________________________________ params :slower ()
  # settingsto slow timing
  def params(:slower) do
    Map.merge(
      params(:default),
      %{}
    )
  end

  # params :slower
end

# Configuration