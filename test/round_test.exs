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
    max_dice = 5
    players = [1,2]
    assert {notifications, r} = Round.start(players, max_dice)
    assert length(notifications) == length(players) + 1
    [notification | rest] = notifications
    notifications = rest
    assert {:notify_player, :private, 1, {:new_hand, _}} = notification
    [notification | rest] = notifications
    notifications = rest
    assert {:notify_player, :private, 2, {:new_hand, _}} = notification
    [notification | _] = notifications
    assert {:notify_player, :public, r.current_player_id, :move} == notification

    assert %Round{
             instructions: [],
             max_dice: ^max_dice,
             remaining_players: players,
             all_players: players,
             hands: [_, _],
             current_bid: {0, 0}
           } = r
  end

  test "unauthorized move" do
    {_, initial_round} = Round.start([1, 2], 5)
    assert %Round{current_player_id: 1} = initial_round

    assert {_, new_round} = Round.move(initial_round, 1, {:outbid, {2, 2}})
    assert {instructions, new_round} = Round.move(new_round, 1, {:outbid, {3, 3}})
    assert %Round{current_player_id: 2, current_bid: {2, 2}} = new_round
    assert Enum.member?(instructions, notify_player_instruction(:public, 1, :unauthorized_move))
  end

  test "outbid move to next player" do
    {_, initial_round} = Round.start([1, 2], 5)
    assert %Round{current_player_id: 1} = initial_round

    assert {instructions, new_round} = Round.move(initial_round, 1, {:outbid, {2, 2}})
    assert %Round{current_player_id: 2, current_bid: {2, 2}} = new_round
    assert Enum.member?(instructions, notify_player_instruction(:public, 2, :move))

    assert {instructions, new_round} = Round.move(new_round, 2, {:outbid, {3, 3}})
    assert Enum.member?(instructions, notify_player_instruction(:public, 1, :move))
    assert %Round{current_player_id: 1, current_bid: {3, 3}} = new_round

    assert {instructions, new_round} = Round.move(new_round, 1, {:outbid, {4, 4}})
    assert %Round{current_player_id: 2, current_bid: {4, 4}} = new_round
    assert Enum.member?(instructions, notify_player_instruction(:public, 2, :move))
  end

  test "outbid does not move to next player if bid illegal" do
    {_, round} = Round.start([1, 2], 5)
    assert %Round{current_player_id: 1, current_bid: {0, 0}} = round
    assert {_, round} = Round.move(round, 1, {:outbid, {2, 2}})
    assert %Round{current_player_id: 2, current_bid: {2, 2}} = round

    assert {instructions, round} = Round.move(round, 2, {:outbid, {2, 2}})
    assert %Round{current_player_id: 2, current_bid: {2, 2}} = round
    assert Enum.member?(instructions, notify_player_instruction(:public, 2, :illegal_bid))

    assert {instructions, round} = Round.move(round, 2, {:outbid, {4, 4}})
    assert %Round{current_player_id: 1, current_bid: {4, 4}} = round
    assert Enum.member?(instructions, notify_player_instruction(:public, 1, :move))

    assert {instructions, round} = Round.move(round, 1, {:outbid, {6, 2}})
    assert %Round{current_player_id: 1, current_bid: {4, 4}} = round
    assert Enum.member?(instructions, notify_player_instruction(:public, 1, :illegal_bid))

    assert {instructions, round} = Round.move(round, 1, {:outbid, {6, 4}})
    assert %Round{current_player_id: 2, current_bid: {6, 4}} = round
    assert Enum.member?(instructions, notify_player_instruction(:public, 2, :move))

    assert {instructions, round} = Round.move(round, 2, {:outbid, {3, 1}})
    assert %Round{current_player_id: 1, current_bid: {3, 1}} = round
    assert Enum.member?(instructions, notify_player_instruction(:public, 1, :move))

    assert {instructions, round} = Round.move(round, 1, {:outbid, {2, 1}})
    assert %Round{current_player_id: 1, current_bid: {3, 1}} = round
    assert Enum.member?(instructions, notify_player_instruction(:public, 1, :illegal_bid))
  end

  test "cannot outbid with face 1 die on start of round" do
    {_, round} = Round.start([1, 2], 5)
    assert %Round{current_player_id: 1, current_bid: {0, 0}} = round
    assert {instructions, round} = Round.move(round, 1, {:outbid, {3, 1}})
    assert %Round{current_player_id: 1, current_bid: {0, 0}} = round
    assert Enum.member?(instructions, notify_player_instruction(:public, 1, :illegal_bid))
  end

  test "cannot outbid with same bid" do
    {_, round} = Round.start([1, 2], 5)
    assert %Round{current_player_id: 1, current_bid: {0, 0}} = round
    assert {instructions, round} = Round.move(round, 1, {:outbid, {3, 2}})
    assert %Round{current_player_id: 2, current_bid: {3, 2}} = round
    assert Enum.member?(instructions, notify_player_instruction(:public, 2, :move))
    assert {instructions, round} = Round.move(round, 2, {:outbid, {3, 2}})
    assert %Round{current_player_id: 2, current_bid: {3, 2}} = round
    assert Enum.member?(instructions, notify_player_instruction(:public, 2, :illegal_bid))
  end

  test "cannot outbid with face 1 die when new count lower then half the actual count" do
    {_, round} = Round.start([1, 2], 5)
    assert %Round{current_player_id: 1, current_bid: {0, 0}} = round

    assert {instructions, round} = Round.move(round, 1, {:outbid, {5, 5}})
    assert %Round{current_player_id: 2, current_bid: {5, 5}} = round
    assert Enum.member?(instructions, notify_player_instruction(:public, 2, :move))

    assert {instructions, round} = Round.move(round, 2, {:outbid, {2, 1}})
    assert %Round{current_player_id: 2, current_bid: {5, 5}} = round
    assert Enum.member?(instructions, notify_player_instruction(:public, 2, :illegal_bid))
  end

  test "outbid with face 1 die" do
    {_, round} = Round.start([1, 2], 5)
    assert %Round{current_player_id: 1, current_bid: {0, 0}} = round

    assert {instructions, round} = Round.move(round, 1, {:outbid, {3, 2}})
    assert %Round{current_player_id: 2, current_bid: {3, 2}} = round
    assert Enum.member?(instructions, notify_player_instruction(:public, 2, :move))

    assert {instructions, round} = Round.move(round, 2, {:outbid, {2, 1}})
    assert %Round{current_player_id: 1, current_bid: {2, 1}} = round
    assert Enum.member?(instructions, notify_player_instruction(:public, 1, :move))

    assert {instructions, round} = Round.move(round, 1, {:outbid, {5, 1}})
    assert %Round{current_player_id: 2, current_bid: {5, 1}} = round
    assert Enum.member?(instructions, notify_player_instruction(:public, 2, :move))
  end

  test "outbid" do
    {_, round} = Round.start([1, 2], 5)
    assert %Round{current_player_id: 1, current_bid: {0, 0}} = round

    assert {instructions, round} = Round.move(round, 1, {:outbid, {5, 5}})
    assert %Round{current_player_id: 2, current_bid: {5, 5}} = round
    assert Enum.member?(instructions, notify_player_instruction(:public, 2, :move))

    assert {instructions, round} = Round.move(round, 2, {:outbid, {3, 1}})
    assert %Round{current_player_id: 1, current_bid: {3, 1}} = round
    assert Enum.member?(instructions, notify_player_instruction(:public, 1, :move))

    assert {instructions, round} = Round.move(round, 1, {:outbid, {7, 5}})
    assert %Round{current_player_id: 2, current_bid: {7, 5}} = round
    assert Enum.member?(instructions, notify_player_instruction(:public, 2, :move))

    assert {instructions, round} = Round.move(round, 2, {:outbid, {4, 1}})
    assert %Round{current_player_id: 1, current_bid: {4, 1}} = round
    assert Enum.member?(instructions, notify_player_instruction(:public, 1, :move))

    assert {instructions, round} = Round.move(round, 1, {:outbid, {5, 1}})
    assert %Round{current_player_id: 2, current_bid: {5, 1}} = round
    assert Enum.member?(instructions, notify_player_instruction(:public, 2, :move))
  end

  test "cannot calza at start of round" do
    {_, round} = Round.start([1, 2], 5)
    assert %Round{current_player_id: 1, current_bid: {0, 0}} = round

    assert {instructions, round} = Round.move(round, 1, :calza)
    assert %Round{current_player_id: 1, current_bid: {0, 0}} = round
    assert Enum.member?(instructions, notify_player_instruction(:public, 1, :illegal_move))
  end

  test "calza gives a dice back to the player if he's right" do
    {_, round} = Round.start([1, 2], 5)
    assert %Round{current_player_id: 1, current_bid: {0, 0}} = round

    p1_hand = Enum.at(round.hands, 0)
    p1_hand = %{p1_hand | hand: %DiceHand{p1_hand.hand | dice: [5, 5, 5, 5, 5]}}
    p2_hand = Enum.at(round.hands, 1)
    p2_hand = %{p2_hand | hand: %DiceHand{p2_hand.hand | dice: [5, 5, 5, 5], remaining_dice: 4}}
    round = %Round{round | hands: List.replace_at(round.hands, 0, p1_hand)}
    round = %Round{round | hands: List.replace_at(round.hands, 1, p2_hand)}

    assert {instructions, round} = Round.move(round, 1, {:outbid, {9, 5}})
    assert %Round{current_player_id: 2, current_bid: {9, 5}} = round
    assert Enum.member?(instructions, notify_player_instruction(:public, 2, :move))

    assert {instructions, round} = Round.move(round, 2, :calza)
    assert %Round{current_player_id: 2, current_bid: {0, 0}} = round
    assert Enum.member?(instructions, notify_player_instruction(:public, 2, :move))
    assert Enum.member?(instructions, notify_player_instruction(:public, 2, :successful_calza))
    assert length(Enum.at(round.hands, 1).hand.dice) == 5
    assert Enum.at(round.hands, 1).hand.remaining_dice == 5
  end

  test "calza takes a dice if the player is wrong" do
    {_, round} = Round.start([1, 2], 5)
    assert %Round{current_player_id: 1, current_bid: {0, 0}} = round

    p1_hand = Enum.at(round.hands, 0)
    p1_hand = %{p1_hand | hand: %DiceHand{p1_hand.hand | dice: [5, 5, 5, 5, 5]}}
    p2_hand = Enum.at(round.hands, 1)
    p2_hand = %{p2_hand | hand: %DiceHand{p2_hand.hand | dice: [5, 5, 5, 5, 5], remaining_dice: 5}}
    round = %Round{round | hands: List.replace_at(round.hands, 0, p1_hand)}
    round = %Round{round | hands: List.replace_at(round.hands, 1, p2_hand)}

    assert {instructions, round} = Round.move(round, 1, {:outbid, {9, 5}})
    assert %Round{current_player_id: 2, current_bid: {9, 5}} = round
    assert Enum.member?(instructions, notify_player_instruction(:public, 2, :move))

    assert {instructions, round} = Round.move(round, 2, :calza)
    assert %Round{current_player_id: 2, current_bid: {0, 0}} = round
    assert Enum.member?(instructions, notify_player_instruction(:public, 2, :move))
    assert Enum.member?(instructions, notify_player_instruction(:public, 2, :unsuccessful_calza))

    assert length(Enum.at(round.hands, 1).hand.dice) == 4
    assert Enum.at(round.hands, 1).hand.remaining_dice == 4
  end

  test "player that calls calza regardless of result is the next to play" do
    {_, round} = Round.start([1, 2], 5)
    assert %Round{current_player_id: 1, current_bid: {0, 0}} = round

    assert {instructions, round} = Round.move(round, 1, {:outbid, {9, 5}})
    assert %Round{current_player_id: 2, current_bid: {9, 5}} = round
    assert Enum.member?(instructions, notify_player_instruction(:public, 2, :move))

    assert {instructions, round} = Round.move(round, 2, :calza)
    assert %Round{current_player_id: 2, current_bid: {0, 0}} = round
    assert Enum.member?(instructions, notify_player_instruction(:public, 2, :move))
  end
end
