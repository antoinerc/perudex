defmodule Perudex.Bid do
  alias __MODULE__

  @enforce_keys [:count, :value]
  defstruct [:count, :value]

  @type t :: %Bid{
          count: integer(),
          value: integer()
        }

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
