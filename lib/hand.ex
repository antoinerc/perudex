defmodule Perudo.Hand do
  @moduledoc """
  Provides functions to manipulate a hand of dice in Perudo.
  """
  alias __MODULE__

  defstruct [:dice, :remaining_dice]

  @type t :: %Hand{dice: [die], remaining_dice: integer()}
  @type die :: 1..6

  def new(0) do
    %Hand{dice: [], remaining_dice: 0}
  end

  def new(%Hand{remaining_dice: remaining_dice} = hand) do
    %Hand{
      hand
      | dice:
          for _ <- 1..remaining_dice do
            :rand.uniform(6)
          end
    }
  end

  def new(remaining_dice) do
    dice =
      for _ <- 1..remaining_dice do
        :rand.uniform(6)
      end

    %Hand{
      dice: dice,
      remaining_dice: remaining_dice
    }
  end

  def add(%Hand{remaining_dice: remaining_dice} = hand) do
    case remaining_dice < 5 do
      true ->
        %Hand{hand | remaining_dice: remaining_dice + 1}

      _ ->
        hand
    end
  end

  def take(%Hand{remaining_dice: 0} = hand) do
    hand
  end

  def take(%Hand{remaining_dice: remaining_dice} = hand) do
    %Hand{hand | remaining_dice: remaining_dice - 1}
  end
end
