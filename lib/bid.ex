defmodule Perudex.Bid do
  @moduledoc """
  Provides logic to validate a bid.
  """
  alias __MODULE__

  @enforce_keys [:count, :value]
  defstruct [:count, :value]

  @type t :: %Bid{
          count: integer(),
          value: integer()
        }

  @doc """
  Validate that a bid is valid, depending on the current standing bid and the current phase of the game.

  ## Examples
        iex> Perudex.Bid.valid?(%Perudex.Bid{count: 2, value: 3}, %Perudex.Bid{count: 2, value: 2}, :normal)
        true

        iex> Perudex.Bid.valid?(%Perudex.Bid{count: 2, value: 2}, %Perudex.Bid{count: 2, value: 2}, :normal)
        false

        iex> Perudex.Bid.valid?(%Perudex.Bid{count: 5, value: 2}, %Perudex.Bid{count: 2, value: 2}, :normal)
        true

        iex> Perudex.Bid.valid?(%Perudex.Bid{count: 6, value: 6}, %Perudex.Bid{count: 7, value: 6}, :normal)
        false

        iex> Perudex.Bid.valid?(%Perudex.Bid{count: 3, value: 1}, %Perudex.Bid{count: 6, value: 6}, :normal)
        true

        iex> Perudex.Bid.valid?(%Perudex.Bid{count: 7, value: 5}, %Perudex.Bid{count: 3, value: 1}, :normal)
        true
  """
  def valid?(%Bid{} = new_bid, %Bid{} = current_bid, :normal) do
    has_valid_value?(new_bid) &&
      has_valid_count?(new_bid) &&
      not is_starting_with_paco?(new_bid, current_bid) &&
      (new_count_is_higher?(new_bid, current_bid) || new_face_is_higher?(new_bid, current_bid))
  end

  def valid?(%Bid{} = new_bid, %Bid{} = current_bid, :palifico) do
    has_valid_value?(new_bid) &&
      has_valid_count?(new_bid) &&
      new_count_is_higher?(new_bid, current_bid) &&
      not new_face_is_higher?(new_bid, current_bid)
  end

  defp is_starting_with_paco?(%Bid{value: 1}, %Bid{count: 0, value: 0}) do
    true
  end

  defp is_starting_with_paco?(_, _) do
    false
  end

  defp has_valid_value?(%Bid{value: value}) do
    value > 0 && value < 7
  end

  defp has_valid_count?(%Bid{count: count}) do
    count > 0
  end

  defp new_count_is_higher?(%Bid{count: new_count, value: 1}, %Bid{
         count: current_count,
         value: current_value
       })
       when current_value != 1 do
    new_count >= ceil(current_count / 2)
  end

  defp new_count_is_higher?(%Bid{count: new_count, value: new_value}, %Bid{
         count: current_count,
         value: 1
       })
       when new_value != 1 do
    new_count >= current_count * 2 + 1
  end

  defp new_count_is_higher?(%Bid{count: new_count, value: new_value}, %Bid{
         count: current_count,
         value: current_value
       }) do
    new_count > current_count && new_value >= current_value
  end

  defp new_face_is_higher?(
         %Bid{value: new_value} = new_bid,
         %Bid{
           value: 1
         } = current_bid
       ) do
    new_value > 1 && new_count_is_higher?(new_bid, current_bid)
  end

  defp new_face_is_higher?(%Bid{count: new_count, value: new_value}, %Bid{
         count: current_count,
         value: current_value
       }) do
    current_value != 0 && (new_value > current_value && new_count >= current_count)
  end
end
