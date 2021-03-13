defmodule BroTest do
  use ExUnit.Case
  doctest Bro

  defmodule Msg do
    use Bro, [
      "test/messages.hrl",
      "test/accounts.hrl"
    ]
  end

  alias Msg.{Records, Structs}

  test "Empty record->struct conversion" do
    require Records

    assert %Structs.Message{} == Records.message() |> Structs.to_struct()
    assert %Structs.Account{} == Records.account() |> Structs.to_struct()
  end
end
