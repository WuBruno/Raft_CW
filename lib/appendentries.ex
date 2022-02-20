# distributed algorithms, n.dulay, 8 feb 2022
# coursework, raft consensus, v2

defmodule AppendEntries do
  # s = server process state (c.f. this/self)

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

    # Index is not too ahead & last log terms match
    valid_log =
      Log.last_index(s) >= prev_log_index and
        (prev_log_index == 0 or prev_log_term == Log.term_at(s, prev_log_index))

    # Terms between leader and follower should match
    if term == s.curr_term and valid_log do
      s = AppendEntries.append_entries(s, prev_log_index, commit_index, entries)
      match_index = Log.last_index(s)

      s
      |> Server.send(leader, :APPEND_ENTRIES_REPLY, {
        s.curr_term,
        match_index,
        true
      })
      |> State.leaderP(Enum.at(s.servers, leader - 1))
      |> Timer.restart_election_timer()
      |> Debug.message("+arep", {
        leader,
        :APPEND_ENTRIES_REPLY,
        {s.curr_term, match_index, true}
      })
    else
      s
      |> Server.send(leader, :APPEND_ENTRIES_REPLY, {
        s.curr_term,
        0,
        false
      })
      |> Debug.message("+arep", {
        leader,
        :APPEND_ENTRIES_REPLY,
        {s.curr_term, 0, false}
      })
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
            |> AppendEntries.leader_commit_log_entries()

          s.next_index[follower] > 0 ->
            s
            |> State.dec_next_index(follower)
            |> Server.send_append_request(follower)

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

  def leader_commit_log_entries(s) do
    max_commit =
      Map.values(s.match_index)
      |> Enum.sort()
      |> Enum.at(s.majority - 1)

    if max_commit > s.commit_index and Log.term_at(s, max_commit) == s.curr_term,
      do:
        s
        # Commit all uncommited to database and reply client
        |> AppendEntries.leader_commit_logs(s.commit_index + 1, max_commit)
        |> State.commit_index(max_commit)
        |> State.match_index(s.server_num, max_commit),
      else: s
  end

  def leader_commit_logs(s, start_index, end_index) do
    for i <- start_index..end_index do
      request = Log.request_at(s, i)
      result = Server.commit_database(s, request)
      ClientReq.leader_reply_commits(s, request, result)
    end

    s
  end

  def commit_logs_to_database(s, start_index, end_index) do
    for i <- start_index..end_index do
      Server.commit_database(s, Log.request_at(s, i))
    end

    s
  end

  def append_entries(s, last_log_index, leader_commit_index, entries) do
    # Cut stale ahead logs
    # Add any new entries
    s =
      if map_size(entries) > 0 and Log.last_index(s) > last_log_index do
        if Log.term_at(s, last_log_index) != entries[last_log_index + 1].term,
          do: s |> Log.delete_entries_from(last_log_index),
          else: s
      else
        s
      end

    s =
      if last_log_index + map_size(entries) > Log.last_index(s),
        do: s |> Log.merge_entries(entries),
        else: s

    if leader_commit_index > s.commit_index,
      do:
        s
        # Commit newly committed messages to database
        |> AppendEntries.commit_logs_to_database(s.commit_index + 1, leader_commit_index)
        # Update own commit to the leaders commit index
        |> State.commit_index(leader_commit_index),
      else: s
  end
end

# AppendEntriess
