defmodule HandTest do
  use ExUnit.Case
  doctest Perudex.Hand

  alias Perudex.Hand

  test "return a dice hand" do
    dice_hand = Hand.new(%Hand{remaining_dice: 50})
    assert length(dice_hand.dice) == 50
    assert Enum.all?(dice_hand.dice, fn x -> x < 7 && x > 0 end)
  end

  test "add a die to the hand return same hand if hand is full" do
    starting_remaining_dice = 5
    dice_hand = Hand.new(%Hand{remaining_dice: starting_remaining_dice})
    dice_hand_dealed = Hand.add(dice_hand)
    assert dice_hand_dealed.remaining_dice == starting_remaining_dice
  end

  test "add add a die to the remaining dice count" do
    starting_remaining_dice = 4
    dice_hand = Hand.new(%Hand{remaining_dice: starting_remaining_dice})
    dice_hand = Hand.add(dice_hand)
    assert dice_hand.remaining_dice == 5
  end

  test "remove reduce number of remaining dice from the hand" do
    starting_dice = 5
    dice_hand = Hand.new(%Hand{remaining_dice: starting_dice})
    dice_hand = Hand.take(dice_hand)
    assert dice_hand.remaining_dice == starting_dice - 1
  end

  test "does not remove a die from the hand if hand is empty" do
    dice_hand = Perudex.Hand.new(%Hand{remaining_dice: 0})
    dice_hand = Perudex.Hand.take(dice_hand)
    assert dice_hand.remaining_dice == 0
  end
end
