# distributed algorithms, n.dulay, 8 feb 2022
# coursework, raft consensus, v2

defmodule ClientReq do
  # s = server process state (c.f. self/this)

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
