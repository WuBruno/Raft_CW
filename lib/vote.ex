# coursework, raft consensus, v2

defmodule Vote do
  # s = server process state (c.f. self/this)

  def verify_won_election(s, election_term) do
    if State.vote_tally(s) >= s.majority do
      s
      |> State.role(:LEADER)
      |> State.leaderP(s.server_num)
      |> Server.broadcast_append_request({election_term})
      |> Timer.cancel_election_timer()
    else
      s
    end
  end

  def start_election(s) do
    s =
      s
      # Increment term
      |> State.inc_term()
      # |> State.inc_election()
      # Set candidate role
      |> State.role(:CANDIDATE)
      # Reset votes
      |> State.new_voted_by()
      # Vote for self
      |> State.voted_for(s.server_num)
      |> State.add_to_voted_by(s.server_num)

    # Send out votes # TODO: add log content
    s
    |> Server.broadcast(:VOTE_REQUEST, {s.curr_term})
    |> Debug.message("+vreq", {:VOTE_REQUEST, {s.curr_term}})
    # Start election timer
    |> Timer.restart_election_timer()
  end
end

# Vote
