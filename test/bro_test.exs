defmodule BroTest do
  use ExUnit.Case
  doctest Bro

  defmodule TestMod do
    import Bro

    defheaders do
      defheader("test/messages.hrl", records: [:message])
      defheader("test/accounts.hrl")
      defheader("test/custom.hrl", records: [:point], converters: [])

      # This header defines a 'mysterious' record, which defines a tricky 'fn' field
      defheader("test/keywords.hrl", records: [:normal, :mysterious])
    end

  end

  alias TestMod.{Message, Account}

  test "Check only exported records are defined" do
    assert Keyword.has_key?(Message.__info__(:macros), :message) == true
    assert Keyword.has_key?(Message.__info__(:macros), :not_exported_record) == false
  end

  test "Empty record->struct conversion" do
    require TestMod.{Message, Account}

    assert %Message{} == Message.message() |> TestMod.from_record()
    assert %Account{} == Account.account() |> TestMod.from_record()
  end

  test "Empty struct->record conversion" do
    require TestMod.{Message, Account}

    assert %Message{} |> TestMod.to_record() == Message.message()
    assert %Account{} |> TestMod.to_record() == Account.account()
  end

  test "Nil-undefined conversion" do
    require TestMod.Account

    assert %Account{name: "gramos", host: nil} |> TestMod.to_record() ==
      Account.account(name: "gramos", host: :undefined)
    assert %Account{name: "gramos", host: nil} ==
      Account.account(name: "gramos", host: :undefined) |> TestMod.from_record()
  end
end
