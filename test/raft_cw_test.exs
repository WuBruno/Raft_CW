defmodule RaftCwTest do
  use ExUnit.Case
  doctest RaftCw

  test "greets the world" do
    assert RaftCw.hello() == :world
  end
end
