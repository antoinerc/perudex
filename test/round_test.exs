defmodule RoundTest do
  use ExUnit.Case
  doctest Perudo.Round

  alias Perudo.Round
  alias Perudo.DiceHand

  defmacrop notify_player_instruction(visibility, player_id, data) do
    quote do
      {:notify_player, unquote(visibility), unquote(player_id), unquote(data)}
    end
  end

  test "initial round" do
    assert {notifications, _} = Round.start([1, 2], 5)
    assert length(notifications) == 3
  end
end
