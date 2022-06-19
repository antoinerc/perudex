defmodule Perudex.Hand do
  @moduledoc """
  Provides functions to manipulate a hand of dice in Perudex.
  """
  alias __MODULE__

  defstruct [:dice, :remaining_dice, has_palificoed: false]

  @type t :: %Hand{dice: [die], remaining_dice: integer(), has_palificoed: boolean()}
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
  Set has_palificoed to true if the player is dropping to his last die.

  ## Examples:
      iex> Perudex.Hand.take(%Perudex.Hand{remaining_dice: 5})
      %Perudex.Hand{remaining_dice: 4, dice: nil, has_palificoed: false}

      iex> Perudex.Hand.take(%Perudex.Hand{remaining_dice: 0})
      %Perudex.Hand{remaining_dice: 0, dice: nil, has_palificoed: false}

      iex> Perudex.Hand.take(%Perudex.Hand{remaining_dice: 2})
      %Perudex.Hand{remaining_dice: 1, dice: nil, has_palificoed: true}
  """
  def take(%Hand{remaining_dice: 0} = hand) do
    hand
  end

  def take(%Hand{remaining_dice: 2} = hand) do
    %Hand{hand | remaining_dice: 1, has_palificoed: true}
  end

  def take(%Hand{remaining_dice: remaining_dice} = hand) do
    %Hand{hand | remaining_dice: remaining_dice - 1}
  end

  @doc """
  Returns the frequency of a value in the hand of the player

  ## Examples:
      iex> Perudex.Hand.count_pip_frequency(%Perudex.Hand{dice: [5, 2, 3, 3, 1]}, 3)
      2
  """
  @spec count_pip_frequency(Perudex.Hand.t(), integer()) :: integer()
  def count_pip_frequency(%Hand{dice: dice}, pip) do
    frequency = Enum.frequencies(dice)[pip]

    if frequency == nil do
      0
    else
      frequency
    end
  end
end
