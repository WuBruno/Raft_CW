# Bruno Wu (bw1121)
# distributed algorithms, n.dulay, 8 feb 2022
# coursework, raft consensus, v2

defmodule Server do
  # s = server process state (c.f. self/this)

  # _________________________________________________________ Server.start()
  def start(config, server_num) do
    config =
      config
      |> Configuration.node_info("Server", server_num)
      |> Debug.node_starting()

    receive do
      {:BIND, servers, databaseP} ->
        State.initialise(config, server_num, servers, databaseP)
        |> Timer.restart_election_timer()
        |> Configuration.setup_server_crash()
        |> Configuration.setup_leader_crash()
        |> Configuration.setup_server_sleep()
        |> Configuration.setup_leader_sleep()
        |> Server.next()
    end

    # receive
  end

  # start

  defp unreliable_send(s, dest, payload) do
    if Helper.random(100) <= s.config.send_reliability,
      do: send(dest, payload),
      else: Monitor.send_msg(s, {:SEND_FAILED, s.server_num})

    s
  end

  def send(s, targetP, payload) do
    if s.config.send_reliability < 100,
      do: unreliable_send(s, targetP, payload),
      else: send(targetP, payload)

    s
  end

  def send_server(s, target, type, payload) do
    s |> Server.send(Enum.at(s.servers, target - 1), {type, s.server_num, payload})
    s
  end

  def broadcast(s, type, payload) do
    for i <- 1..s.num_servers,
        i != s.server_num,
        do: Server.send_server(s, i, type, payload)

    s
  end

  def commit_database(s, client_request) do
    send(s.databaseP, {:DB_REQUEST, client_request})
    Debug.message(s, "+dreq", {:DB_REQUEST, client_request})

    receive do
      {:DB_REPLY, db_result} = m ->
        Debug.message(s, "-drep", m)
        db_result
    end
  end

  # _________________________________________________________ next()
  def next(s) do
    s =
      receive do
        {:APPEND_ENTRIES_REQUEST, leader, payload} = m ->
          s
          |> Debug.message("-areq", m)
          |> AppendEntries.handle_append_entries_request(leader, payload)

        {:APPEND_ENTRIES_REPLY, follower, payload} = m ->
          s
          |> Debug.message("-arep", m)
          |> AppendEntries.handle_append_entries_reply(follower, payload)

        {:VOTE_REQUEST, candidate, payload} = m ->
          s
          |> Debug.message("-vreq", m)
          |> Vote.handle_vote_request(candidate, payload)

        {:VOTE_REPLY, voter, payload} = m ->
          s
          |> Debug.message("-vrep", m)
          |> Vote.handle_vote_reply(voter, payload)

        {:ELECTION_TIMEOUT, payload} = m ->
          s
          |> Debug.message("-etim", m)
          |> Vote.handle_election_timeout(payload)

        {:APPEND_ENTRIES_TIMEOUT, payload} = m ->
          s
          |> Debug.message("-atim", m)
          |> AppendEntries.handle_append_timeout(payload)

        {:CLIENT_REQUEST, payload} = m ->
          s
          |> Debug.message("-creq", m)
          |> ClientReq.handle_client_request(payload)

        {:SERVER_CRASH} ->
          Debug.info(s, "Server Crashed")
          Process.exit(self(), "Crash Exit")

          s

        {:LEADER_CRASH} ->
          if s.role == :LEADER do
            Debug.info(s, "Leader Crashed")
            Process.exit(self(), "Crash Exit")
          end

          s

        {:SERVER_SLEEP} ->
          Debug.info(s, "Process sleeping")
          Process.sleep(s.config.sleep_time)

          s

        {:LEADER_SLEEP} ->
          if s.role == :LEADER do
            Debug.info(s, "Leader sleeping")
            Process.sleep(s.config.sleep_time)
          end

          s

        unexpected ->
          s |> Debug.info("Unexpected request received #{inspect(unexpected)}")
      end

    # receive

    Server.next(s)
  end

  # next
end

# Server
