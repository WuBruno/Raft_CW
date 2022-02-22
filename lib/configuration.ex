# Bruno Wu (bw1121)
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
      max_client_requests: 1_000,
      # interval(ms) between client requests
      client_request_interval: 5,
      # timeout(ms) for the reply to a client request
      client_reply_timeout: 50,
      # timeout(ms) for election, set randomly in range
      election_timeout_range: 100..200,
      # timeout(ms) for the reply to a append_entries request
      append_entries_timeout: 10,
      # interval(ms) between monitor summaries
      monitor_interval: 500,
      # server_num => crash_after_time (ms), ..
      crash_servers: %{},
      # the leader at these certain times will crash
      crash_leader: [],
      # the following servers will sleep at the specified times
      sleep_servers: %{},
      # the leader at these certain times will sleep
      sleep_leader: [],
      sleep_time: 1000
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

  def params(:single_crash) do
    Map.merge(
      params(:default),
      %{
        crash_servers: %{
          1 => 3_000
        }
      }
    )
  end

  def params(:max_crash) do
    Map.merge(
      params(:default),
      %{
        crash_servers: %{
          1 => 3_000,
          2 => 3_000
        }
      }
    )
  end

  def params(:leader_crash) do
    Map.merge(
      params(:default),
      %{
        crash_leader: [3_000]
      }
    )
  end

  def params(:multi_leader_crash) do
    Map.merge(
      params(:default),
      %{
        crash_leader: [3_000, 5_000]
      }
    )
  end

  # params :slower

  def setup_server_crash(s) do
    if Map.has_key?(s.config.crash_servers, s.server_num) do
      Process.send_after(self(), {:SERVER_CRASH}, s.config.crash_servers[s.server_num])
    end

    s
  end

  def setup_leader_crash(s) do
    for time <- s.config.crash_leader do
      Process.send_after(self(), {:LEADER_CRASH}, time)
    end

    s
  end

  def setup_server_sleep(s) do
    if Map.has_key?(s.config.sleep_servers, s.server_num) do
      Process.send_after(self(), {:SERVER_SLEEP}, s.config.sleep_servers[s.server_num])
    end

    s
  end

  def setup_leader_sleep(s) do
    for time <- s.config.sleep_leader do
      Process.send_after(self(), {:LEADER_SLEEP}, time)
    end

    s
  end
end

# Configuration
