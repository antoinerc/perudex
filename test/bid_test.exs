defmodule BidTest do
  use ExUnit.Case
  doctest Perudex.Bid

  alias Perudex.Bid

  setup_all do
    {:ok, new_game_bid: %Bid{count: 0, value: 0}, normal_bid: %Bid{count: 3, value: 3}}
  end

  test "when count and/or value is higher, valid?/3 returns true", state do
    %Bid{count: count, value: value} = state[:normal_bid]
    assert Bid.valid?(%Bid{count: count + 1, value: value}, state[:normal_bid], :normal)
    assert Bid.valid?(%Bid{count: count, value: value + 1}, state[:normal_bid], :normal)
    assert Bid.valid?(%Bid{count: count + 1, value: value + 1}, state[:normal_bid], :normal)
    assert Bid.valid?(%Bid{count: 3, value: 1}, %Bid{count: 2, value: 1}, :normal)
  end

  test "when count and value is lower or equal, valid?/3 returns false", state do
    %Bid{count: count, value: value} = state[:normal_bid]
    assert not Bid.valid?(%Bid{count: count - 1, value: value}, state[:normal_bid], :normal)
    assert not Bid.valid?(%Bid{count: count, value: value - 1}, state[:normal_bid], :normal)
    assert not Bid.valid?(%Bid{count: count + 1, value: value - 1}, state[:normal_bid], :normal)
    assert not Bid.valid?(%Bid{count: count, value: value}, state[:normal_bid], :normal)
    assert not Bid.valid?(%Bid{count: 2, value: 1}, %Bid{count: 2, value: 1}, :normal)
    assert not Bid.valid?(%Bid{count: 1, value: 1}, %Bid{count: 2, value: 1}, :normal)
  end

  test "when converting to paco and count is invalid, valid?/3 returns false", state do
    %Bid{count: count} = state[:normal_bid]

    assert not Bid.valid?(%Bid{count: ceil(count / 2) - 1, value: 1}, state[:normal_bid], :normal)
  end

  test "when converting from paco and count is invalid, valid?/3 returns false" do
    current_bid = %Bid{count: 3, value: 1}
    assert not Bid.valid?(%Bid{count: 2 * current_bid.count, value: 2}, current_bid, :normal)
  end

  test "when starting with pacos, valid?/3 returns false if phase is normal", state do
    assert not Bid.valid?(%Bid{count: 2, value: 1}, state[:new_game_bid], :normal)
  end

  test "when starting with pacos, valid?/3 returns true if phase is palifico", state do
    assert Bid.valid?(%Bid{count: 2, value: 1}, state[:new_game_bid], :palifico)
  end

  test "when in palifico phase, valid?/3 returns false when value is increased", state do
    assert not Bid.valid?(%Bid{count: 3, value: 4}, state[:normal_bid], :palifico)
    assert not Bid.valid?(%Bid{count: 4, value: 4}, state[:normal_bid], :palifico)
  end

  test "when in palifico phase, valid?/3 returns true when only count is increased", state do
    assert Bid.valid?(%Bid{count: 4, value: 3}, state[:normal_bid], :palifico)
    assert Bid.valid?(%Bid{count: 5, value: 3}, state[:normal_bid], :palifico)
  end
end
