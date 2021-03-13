defmodule BroTest do
  use ExUnit.Case
  doctest Bro

  test "greets the world" do
    assert Bro.hello() == :world
  end
end
