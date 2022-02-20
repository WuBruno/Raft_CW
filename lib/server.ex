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
        |> Server.next()
    end

    # receive
  end

  # start

  def send(s, target, type, payload) do
    send(Enum.at(s.servers, target - 1), {type, s.server_num, payload})
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

  def send_append_request(s, follower) do
    i = s.next_index[follower]

    entries =
      if i < Log.last_index(s),
        do: Log.get_entries(s, (i + 1)..Log.last_index(s)),
        else: %{}

    prev_log_term = if i > 0, do: Log.last_term(s), else: 0

    payload = {s.curr_term, i, prev_log_term, s.commit_index, entries}

    s
    |> Server.send(follower, :APPEND_ENTRIES_REQUEST, payload)
    |> Debug.message("+areq", {follower, :APPEND_ENTRIES_REQUEST, payload})
    |> Timer.restart_append_entries_timer(follower)
  end

  def broadcast(s, type, payload) do
    for i <- 1..s.num_servers,
        i != s.server_num,
        do: Server.send(s, i, type, payload)

    s
  end

  def broadcast_append_request(s) do
    for i <- 1..s.num_servers,
        i != s.server_num,
        do:
          s
          |> Server.send_append_request(i)
          |> Timer.restart_append_entries_timer(i)

    s
  end

  # _________________________________________________________ next()
  def next(s) do
    s =
      receive do
        {:APPEND_ENTRIES_REQUEST, leader, payload} = m ->
          Debug.message(s, "-areq", m)
          s |> AppendEntries.handle_append_entries_request(leader, payload)

        {:APPEND_ENTRIES_REPLY, follower, payload} = m ->
          Debug.message(s, "-arep", m)
          s |> AppendEntries.handle_append_entries_reply(follower, payload)

        {:VOTE_REQUEST, candidate, payload} = m ->
          Debug.message(s, "-vreq", m)
          s |> Vote.handle_vote_request(candidate, payload)

        {:VOTE_REPLY, voter, payload} = m ->
          Debug.message(s, "-vrep", m)
          s |> Vote.handle_vote_reply(voter, payload)

        {:ELECTION_TIMEOUT, {curr_term, _curr_election}} = m ->
          # Don't accept timeouts from past terms
          Debug.message(s, "-etim", m)

          if curr_term < s.curr_term,
            do: s,
            else: s |> Vote.start_election()

        # Configure state

        {:APPEND_ENTRIES_TIMEOUT, {term, follower}} = m ->
          Debug.message(s, "-atim", m)

          if term == s.curr_term,
            # Send heartbeat
            do: s |> Server.send_append_request(follower),
            else: s

        {:CLIENT_REQUEST, %{clientP: clientP, cid: cid} = request} = m ->
          s |> Debug.message("-creq", m)

          cond do
            s.role != :LEADER and s.leaderP != nil ->
              send(clientP, {:CLIENT_REPLY, {cid, :NOT_LEADER, s.leaderP}})

              s
              |> Debug.message(
                "+crep",
                {clientP, {:CLIENT_REPLY, {cid, :NOT_LEADER, s.leaderP}}}
              )

            s.role == :LEADER ->
              s = s |> Log.append_entry(%{term: s.curr_term, request: request})

              s
              |> State.match_index(s.server_num, Log.last_index(s))
              |> State.next_index(s.server_num, Log.last_index(s))
              |> Server.broadcast_append_request()

            true ->
              s
          end

        {:CRASH} ->
          Debug.info(s, "Process sleeping")
          # Process.exit(self(), "Necessary exit")
          Process.sleep(1000)
          Debug.info(s, "Process woke up")
          s

        _unexpected ->
          # omitted
          s
      end

    # receive

    Server.next(s)
  end

  # next
end

# Server
