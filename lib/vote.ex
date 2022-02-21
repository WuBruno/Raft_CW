# Bruno Wu (bw1121)
# coursework, raft consensus, v2

defmodule Vote do
  # s = server process state (c.f. self/this)

  def handle_vote_request(
        s,
        candidate,
        _payload = {
          c_term,
          c_last_log_index,
          c_last_log_term
        }
      ) do
    last_log_term = Log.last_term(s)
    last_log_index = Log.last_index(s)
    current_term = s.curr_term

    valid_log =
      c_last_log_term > last_log_term or
        (c_last_log_term == last_log_term and
           c_last_log_index >= last_log_index)

    valid_term =
      c_term > current_term or
        (current_term == c_term and s.voted_for in [candidate, nil])

    if valid_term and valid_log do
      # Accept vote
      s
      |> State.curr_term(c_term)
      |> State.role(:FOLLOWER)
      |> State.voted_for(candidate)
      |> Server.send(candidate, :VOTE_REPLY, {c_term, true})
      |> Debug.message("+vrep", {candidate, c_term, true})
      |> Timer.restart_election_timer()
    else
      # Reject vote
      s
      |> Server.send(candidate, :VOTE_REPLY, {current_term, false})
      |> Debug.message("+vrep", {candidate, current_term, false})
    end
  end

  def handle_election_timeout(s, _payload = {curr_term, _election_term}) do
    unless curr_term < s.curr_term,
      do: s |> start_election(),
      else: s
  end

  def handle_vote_reply(s, voter, _payload = {term, vote_granted}) do
    current_role = s.role
    current_term = s.curr_term

    cond do
      current_role == :CANDIDATE and
        term == current_term and
          vote_granted ->
        s
        |> State.add_to_voted_by(voter)
        |> verify_won_election()

      term > current_term ->
        s
        |> State.curr_term(term)
        |> Vote.become_follower()

      true ->
        s
    end
  end

  def verify_election_status(s, leader, term) do
    s =
      cond do
        # Server's term outdated, update itself and follow new leader
        term > s.curr_term ->
          s
          |> State.curr_term(term)
          |> Vote.become_follower(leader)

        # Server was competing election but has lost
        term == s.curr_term and s.role == :CANDIDATE ->
          s |> Vote.become_follower(leader)

        # Otherwise do nothing
        true ->
          s
      end

    # Update timer if the leader's is valid
    if term == s.curr_term,
      do: s |> Timer.restart_election_timer(),
      else: s
  end

  def become_follower(s),
    do:
      s
      |> State.voted_for(nil)
      |> State.role(:FOLLOWER)
      |> Timer.restart_election_timer()

  def become_follower(s, new_leader),
    do:
      s
      |> Vote.become_follower()
      |> State.leaderP(Enum.at(s.servers, new_leader - 1))

  defp start_election(s) do
    # Update s
    s =
      s
      # Increment term
      |> State.inc_term()
      # Set candidate role
      |> State.role(:CANDIDATE)
      # Reset votes
      |> State.new_voted_by()
      # Vote for self
      |> State.voted_for(s.server_num)
      |> State.add_to_voted_by(s.server_num)

    # Required term information
    last_log_index = Log.last_index(s)
    last_log_term = Log.last_term(s)

    s
    |> Server.broadcast(:VOTE_REQUEST, {s.curr_term, last_log_index, last_log_term})
    |> Debug.message("+vreq", {:VOTE_REQUEST, {s.curr_term, last_log_index, last_log_term}})
    |> Timer.restart_election_timer()
  end

  defp verify_won_election(s) do
    if State.vote_tally(s) >= s.majority,
      do:
        s
        |> State.role(:LEADER)
        |> State.leaderP(Enum.at(s.servers, s.server_num - 1))
        |> State.init_next_index()
        |> State.init_match_index()
        |> Timer.cancel_election_timer()
        |> AppendEntries.broadcast_append_request()
        |> Debug.info("Became Leader"),
      else: s
  end
end

# Vote
