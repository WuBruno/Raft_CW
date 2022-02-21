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
        |> Configuration.setup_crash()
        |> Configuration.setup_leader_crash()
        |> Server.next()
    end

    # receive
  end

  # start

  def send(s, target, type, payload) do
    send(Enum.at(s.servers, target - 1), {type, s.server_num, payload})
    s
  end

  def broadcast(s, type, payload) do
    for i <- 1..s.num_servers,
        i != s.server_num,
        do: Server.send(s, i, type, payload)

    s
  end

  def commit_database(s, client_request) do
    send(s.databaseP, {:DB_REQUEST, client_request})
    Debug.message(s, "+dreq", {:DB_REQUEST, client_request})

    # Return reply
    receive do
      {:DB_REPLY, db_result} ->
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

        {:CRASH} ->
          s |> Debug.info("Process sleeping")
          # Process.exit(self(), "Necessary exit")
          Process.sleep(1000)
          s |> Debug.info(s, "Process woke up")

        {:LEADER_CRASH} ->
          if s.role == :LEADER do
            s |> Debug.info("Leader sleeping")
            # Process.exit(self(), "Necessary exit")
            Process.sleep(1000)
            s |> Debug.info(s, "Process woke up")
          else
            s
          end

        unexpected ->
          s |> Debug.info("Unexpected request received #{inspect(unexpected)}")
      end

    # receive

    Server.next(s)
  end

  # next
end

# Server
