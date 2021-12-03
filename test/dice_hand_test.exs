defmodule DiceHandTest do
  use ExUnit.Case
  doctest Perudo

  test "return a dice hand" do
    dice_hand = Perudo.DiceHand.new(50)
    assert length(dice_hand.dice) == 50
    assert Enum.all?(dice_hand.dice, fn x -> x < 7 && x > 0 end)
  end

  test "add a die to the hand return same hand if hand is full" do
    dice_hand = Perudo.DiceHand.new(5)
    dice_hand_dealed = Perudo.DiceHand.add(dice_hand, 1)
    assert length(dice_hand.dice) == 5
    assert dice_hand == dice_hand_dealed
  end

  test "remove a die from the hand" do
    dice_hand = Perudo.DiceHand.new(5)
    dice_hand = Perudo.DiceHand.take(dice_hand)
    assert length(dice_hand.dice) == 4
  end

  test "does not remove a die from the hand if hand is empty" do
    dice_hand = Perudo.DiceHand.new(0)
    dice_hand = Perudo.DiceHand.take(dice_hand)
    assert dice_hand.dice == []
  end
end
