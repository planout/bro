defmodule BroTest do
  use ExUnit.Case
  doctest Bro

  defmodule Msg do
    use Bro, [
      {"test/messages.hrl", only: [:message]},
      "test/accounts.hrl"
    ]
  end

  alias Msg.{Records, Structs}

  test "Check only exported records are defined" do
    require Records

    assert Keyword.has_key?(Records.__info__(:macros), :message) == true
    assert Keyword.has_key?(Records.__info__(:macros), :not_exported_record) == false
  end

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
