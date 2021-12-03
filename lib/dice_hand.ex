defmodule Perudo.DiceHand do
  alias __MODULE__

  defstruct [:dice, :holding_dice]

  @type t :: %DiceHand{dice: [die], holding_dice: integer()}
  @type die :: 1..6

  def new(dice_count) when dice_count == 0 do
    %DiceHand{dice: []}
  end

  def new(dice_count) do
    %DiceHand{
      dice:
        for _ <- 1..dice_count do
          :rand.uniform(6)
        end,
      holding_dice: dice_count
    }
  end

  @spec add(t(), die()) ::
          t()
  def add(hand, die) do
    case length(hand.dice) < hand.holding_dice do
      true -> %DiceHand{hand | dice: [die | hand.dice]}
      _ -> hand
    end
  end

  def take(%DiceHand{dice: []} = hand) do
    hand
  end

  def take(%DiceHand{dice: [_ | remaining_dice], holding_dice: holding_dice} = hand) do
    %DiceHand{hand | dice: remaining_dice, holding_dice: holding_dice - 1}
  end
end
