defmodule Perudo.DiceHand do
  alias __MODULE__

  defstruct [:dice, :remaining_dice]

  @type t :: %DiceHand{dice: [die], remaining_dice: integer()}
  @type die :: 1..6

  def new(0) do
    %DiceHand{dice: []}
  end

  def new(%DiceHand{remaining_dice: remaining_dice}) do
    %DiceHand{
      dice:
        for _ <- 1..remaining_dice do
          :rand.uniform(6)
        end,
    }
  end

  def new(dice_count) do
    %DiceHand{
      dice:
        for _ <- 1..dice_count do
          :rand.uniform(6)
        end,
      remaining_dice: dice_count
    }
  end

  @spec add(t(), die()) ::
          t()
  def add(%DiceHand{remaining_dice: remaining_dice, dice: dice} = hand, die) do
    case length(dice) < 5 do
      true ->
        %DiceHand{hand | dice: [die | dice], remaining_dice: remaining_dice + 1}
      _ -> hand
    end
  end

  def take(%DiceHand{dice: []} = hand) do
    hand
  end

  def take(%DiceHand{dice: [_ | dice], remaining_dice: remaining_dice} = hand) do
    %DiceHand{hand | dice: dice, remaining_dice: remaining_dice - 1}
  end
end
