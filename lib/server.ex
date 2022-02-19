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
        |> Server.setup_crash()
        |> Server.next()
    end

    # receive
  end

  def setup_crash(s) do
    if Map.has_key?(s.config.crash_servers, s.server_num) do
      Process.send_after(self(), {:CRASH}, s.config.crash_servers[s.server_num])
    end

    s
  end

  # start

  def send(s, target, type, payload) do
    send(Enum.at(s.servers, target - 1), {type, s.server_num, payload})
    s
  end

  def send_append_request(s, follower) do
    payload = {s.curr_term}

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

  def broadcast_append_request(s, payload) do
    for i <- 1..s.num_servers,
        i != s.server_num,
        do:
          s
          |> Server.send(i, :APPEND_ENTRIES_REQUEST, payload)
          |> Timer.restart_append_entries_timer(i)

    s |> Debug.message("+vall", {:APPEND_ENTRIES_REQUEST, payload})
  end

  # _________________________________________________________ next()
  def next(s) do
    s =
      receive do
        {:APPEND_ENTRIES_REQUEST, leader, {term}} = m ->
          # omitted
          Debug.message(s, "-areq", m)

          s =
            if term > s.curr_term do
              s
              |> State.curr_term(term)
              |> State.voted_for(nil)
              |> State.role(:FOLLOWER)
              |> State.leaderP(leader)
            else
              s
            end

          s =
            if(term == s.curr_term and s.role == :CANDIDATE) do
              s
              |> State.role(:FOLLOWER)
              |> State.leaderP(leader)
            else
              s
            end

          if term == s.curr_term do
            s
            |> Server.send(leader, :APPEND_ENTRIES_REPLY, {s.curr_term, true})
            |> Timer.restart_election_timer()
            |> Debug.message("+arep", {leader, :APPEND_ENTRIES_REPLY, {s.curr_term, true}})
          else
            s
            |> Server.send(leader, :APPEND_ENTRIES_REPLY, {s.curr_term, false})
            |> Debug.message("+arep", {leader, :APPEND_ENTRIES_REPLY, {s.curr_term, false}})
          end

        {:APPEND_ENTRIES_REPLY, _follower, {term, _success}} = m ->
          Debug.message(s, "-arep", m)

          cond do
            term == s.curr_term and s.role == :LEADER ->
              s

            term > s.curr_term ->
              s
              |> State.curr_term(term)
              |> State.role(:FOLLOWER)
              |> State.voted_for(nil)

            true ->
              s
          end

        {:VOTE_REQUEST, sender, {election_term}} = m ->
          Debug.message(s, "-vreq", m)

          valid_term =
            election_term > s.curr_term or
              (s.curr_term == election_term and s.voted_for in [sender, nil])

          if valid_term do
            # Accept vote
            s
            |> State.curr_term(election_term)
            |> State.role(:FOLLOWER)
            |> State.voted_for(sender)
            |> Server.send(sender, :VOTE_REPLY, {election_term, :ACCEPT})
            |> Debug.message("+vrep", {s.server_num, election_term, :ACCEPT})
            |> Timer.restart_election_timer()

            # |> State.curr_election(election_term)
          else
            # Reject vote
            s
            |> Server.send(sender, :VOTE_REPLY, {s.curr_term, :REJECT})
            |> Debug.message("+vrep", {s.curr_term, :REJECT})
          end

        {:VOTE_REPLY, sender, {election_term, response}} = m ->
          Debug.message(s, "-vrep", m)

          cond do
            s.role == :CANDIDATE and
              election_term == s.curr_term and
                response == :ACCEPT ->
              s
              |> State.add_to_voted_by(sender)
              |> Vote.verify_won_election(election_term)

            election_term > s.curr_term ->
              s
              |> State.curr_term(election_term)
              |> State.role(:FOLLOWER)
              |> State.voted_for(nil)
              |> Timer.cancel_election_timer()

            true ->
              s
          end

        {:ELECTION_TIMEOUT, {curr_term, _curr_election}} ->
          # Don't accept timeouts from past terms
          Debug.message(s, "-etim", "")

          if curr_term < s.curr_term do
            s
          else
            s |> Vote.start_election()
          end

        # Configure state

        {:APPEND_ENTRIES_TIMEOUT, {term, follower}} ->
          if term == s.curr_term do
            # Send heartbeat
            s |> Server.send_append_request(follower)
          else
            s
          end

        {:CLIENT_REQUEST, _msg} ->
          # omitted
          s

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
