# distributed algorithms, n.dulay, 8 feb 2022
# coursework, raft consensus, v2

defmodule AppendEntries do
  # s = server process state (c.f. this/self)

  defp send_append_request(s, follower) do
    prev_log_index = s.next_index[follower]

    entries =
      if prev_log_index < Log.last_index(s),
        do: Log.get_entries(s, (prev_log_index + 1)..Log.last_index(s)),
        else: %{}

    prev_log_term =
      if prev_log_index > Log.last_index(s), do: 0, else: Log.term_at(s, prev_log_index)

    payload = {s.curr_term, prev_log_index, prev_log_term, s.commit_index, entries}

    s
    |> Server.send(follower, :APPEND_ENTRIES_REQUEST, payload)
    # |> Debug.message("+areq", {follower, :APPEND_ENTRIES_REQUEST, payload})
    |> Timer.restart_append_entries_timer(follower)
  end

  defp send_append_reply(s, leader, payload) do
    s
    |> Server.send(leader, :APPEND_ENTRIES_REPLY, payload)
    |> Debug.message("+arep", {leader, :APPEND_ENTRIES_REPLY, payload})
  end

  def broadcast_append_request(s) do
    for follower <- 1..s.num_servers,
        follower != s.server_num,
        do:
          s
          |> send_append_request(follower)
          |> Timer.restart_append_entries_timer(follower)

    s
  end

  def handle_append_entries_request(
        s,
        leader,
        _payload = {
          term,
          prev_log_index,
          prev_log_term,
          commit_index,
          entries
        }
      ) do
    # Verify election
    s = Vote.verify_election_status(s, leader, term)

    # Debug.info(
    #   s,
    #   "#{prev_log_index} #{prev_log_term} #{Log.last_index(s)}"
    # )

    # Index is not too ahead & last log terms match
    valid_log =
      if Log.last_index(s) >= prev_log_index,
        do: prev_log_index == 0 or prev_log_term == Log.term_at(s, prev_log_index),
        else: false

    # Terms between leader and follower should match
    if term == s.curr_term and valid_log do
      s = append_log_entries(s, prev_log_index, commit_index, entries)
      match_index = Log.last_index(s)

      s
      |> send_append_reply(leader, {s.curr_term, match_index, true})
      |> State.leaderP(Enum.at(s.servers, leader - 1))
    else
      s
      |> send_append_reply(leader, {s.curr_term, 0, false})
    end
  end

  def handle_append_entries_reply(
        s,
        follower,
        _payload = {
          term,
          match_index,
          success
        }
      ) do
    cond do
      term == s.curr_term and s.role == :LEADER ->
        cond do
          success and match_index >= s.match_index[follower] ->
            s
            |> State.next_index(follower, match_index)
            |> State.match_index(follower, match_index)
            |> leader_commit_log_entries()

          s.next_index[follower] > 0 ->
            s
            |> State.dec_next_index(follower)

          true ->
            s
        end

      term > s.curr_term ->
        s
        |> State.curr_term(term)
        |> Vote.become_follower()

      true ->
        s
    end
  end

  def handle_append_timeout(s, _payload = {term, follower}),
    do:
      if(term == s.curr_term,
        # Send heartbeat
        do: s |> send_append_request(follower),
        else: s
      )

  defp leader_commit_log_entries(s) do
    # Get the maximum commit with majority's commit
    max_commit =
      Map.values(s.match_index)
      |> Enum.sort()
      |> Enum.at(s.majority - 1)

    # Debug.info(s, "Max commit is #{max_commit} #{s.commit_index} #{inspect(s.match_index)}")

    if max_commit > s.commit_index and Log.term_at(s, max_commit) == s.curr_term do
      s
      # Commit all uncommited to database and reply client
      |> leader_commit_logs(s.commit_index + 1, max_commit)
      |> State.commit_index(max_commit)
      |> State.match_index(s.server_num, max_commit)
    else
      s
    end
  end

  defp leader_commit_logs(s, start_index, end_index) do
    for i <- start_index..end_index do
      request = Log.request_at(s, i)
      result = Server.commit_database(s, request)
      ClientReq.leader_reply_commits(s, request, result)
    end

    s
  end

  defp append_log_entries(s, last_log_index, leader_commit_index, entries) do
    # Cut stale ahead logs
    s =
      if map_size(entries) > 0 and Log.last_index(s) > last_log_index,
        do:
          if(Log.term_at(s, last_log_index) != entries[last_log_index + 1].term,
            do: s |> Log.delete_entries_from(last_log_index + 1),
            else: s
          ),
        else: s

    # Add any new entries
    s =
      if last_log_index + map_size(entries) > Log.last_index(s),
        do: s |> Log.merge_entries(entries),
        else: s

    # Check if any new requests to commit
    if leader_commit_index > s.commit_index,
      do:
        s
        # Commit newly committed messages to database
        |> commit_logs_to_database(s.commit_index + 1, leader_commit_index)
        # Update own commit to the leaders commit index
        |> State.commit_index(leader_commit_index),
      else: s
  end

  defp commit_logs_to_database(s, start_index, end_index) do
    # Debug.info(
    #   s,
    #   "#{start_index} #{end_index} #{Log.last_index(s)}"
    # )

    for i <- start_index..end_index do
      Server.commit_database(s, Log.request_at(s, i))
    end

    s
  end
end

# AppendEntriess
