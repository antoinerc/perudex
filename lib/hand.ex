defmodule Perudex.Hand do
  @moduledoc """
  Provides functions to manipulate a hand of dice in Perudex.
  """
  alias __MODULE__

  defstruct [:dice, :remaining_dice]

  @type t :: %Hand{dice: [die], remaining_dice: integer()}
  @type die :: 1..6

  @doc """
  Initialize a new hand for a player given his allowed dice holding count.

  ## Examples:
      iex> hand = Perudex.Hand.new(%Perudex.Hand{remaining_dice: 5})
      iex> %{remaining_dice: 5} = hand
      iex> length(hand.dice) == hand.remaining_dice
  """
  def new(%Hand{remaining_dice: remaining_dice} = hand) do
    %Hand{
      hand
      | dice:
          for _ <- 1..remaining_dice do
            :rand.uniform(6)
          end
    }
  end

  @doc """
  Add a die to the hand if the maximum defined by game rules is not busted.

  ## Examples:
      iex> Perudex.Hand.add(%Perudex.Hand{remaining_dice: 4})
      %Perudex.Hand{remaining_dice: 5, dice: nil}
  """
  def add(%Hand{remaining_dice: remaining_dice} = hand) do
    case remaining_dice < 5 do
      true ->
        %Hand{hand | remaining_dice: remaining_dice + 1}

      _ ->
        hand
    end
  end

  @doc """
  Remove a die from the hand if it is not empty.

  ## Examples:
      iex> Perudex.Hand.take(%Perudex.Hand{remaining_dice: 5})
      %Perudex.Hand{remaining_dice: 4, dice: nil}

      iex> Perudex.Hand.take(%Perudex.Hand{remaining_dice: 0})
      %Perudex.Hand{remaining_dice: 0, dice: nil}
  """
  def take(%Hand{remaining_dice: 0} = hand) do
    hand
  end

  def take(%Hand{remaining_dice: remaining_dice} = hand) do
    %Hand{hand | remaining_dice: remaining_dice - 1}
  end
end
