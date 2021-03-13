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

  test "Empty struct->record conversion" do
    require Records

    assert %Structs.Message{} |> Structs.to_record() == Records.message()
    assert %Structs.Account{} |> Structs.to_record() == Records.account()
  end
end
