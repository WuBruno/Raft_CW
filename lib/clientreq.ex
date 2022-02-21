# distributed algorithms, n.dulay, 8 feb 2022
# coursework, raft consensus, v2

defmodule ClientReq do
  # s = server process state (c.f. self/this)

  def handle_client_request(s, %{clientP: clientP, cid: cid} = payload) do
    cond do
      s.role != :LEADER and s.leaderP != nil ->
        send(clientP, {:CLIENT_REPLY, {cid, :NOT_LEADER, s.leaderP}})

        s
        |> Debug.message(
          "+crep",
          {clientP, {:CLIENT_REPLY, {cid, :NOT_LEADER, s.leaderP}}}
        )

      # |> Debug.info("Our new leader is #{inspect(s.leaderP)} #{inspect(s.servers)}")

      s.role == :LEADER ->
        # Only append if it is a new request
        repeated =
          Map.values(s.log)
          |> Enum.any?(fn %{term: _term, request: %{clientP: _clientP, cid: x}} -> x == cid end)

        s =
          if not repeated do
            s |> Log.append_entry(%{term: s.curr_term, request: payload})
          else
            send(clientP, {:CLIENT_REPLY, {cid, :OK, s.leaderP}})
            s |> Debug.message(
              "+crep",
              {clientP, {:CLIENT_REPLY, {cid, :OK, s.leaderP}}}
            )
          end

        s
        |> State.match_index(s.server_num, Log.last_index(s))
        |> State.next_index(s.server_num, Log.last_index(s))
        |> AppendEntries.broadcast_append_request()

      true ->
        s
    end
  end

  def leader_reply_commits(s, _request = %{clientP: clientP, cid: cid}, result) do
    send(clientP, {:CLIENT_REPLY, {cid, result, s.leaderP}})

    s
    |> Monitor.send_msg({:CLIENT_REQUEST, s.server_num})
    |> Debug.message(
      "+crep",
      {clientP, {:CLIENT_REPLY, {cid, result, s.leaderP}}}
    )
  end
end

# Clientreq
