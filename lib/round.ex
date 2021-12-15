defmodule Perudo.Round do
  alias __MODULE__

  alias Perudo.DiceHand

  defstruct [
    :current_player_id,
    :all_players,
    :remaining_players,
    :current_bid,
    :hands,
    :max_dice,
    :instructions
  ]

  @type t :: %Round{
          current_player_id: player_id,
          all_players: [player_id],
          current_bid: bid(),
          remaining_players: [player_id],
          hands: [%{player_id: player_id, hand: DiceHand.t()}],
          max_dice: integer(),
          instructions: [instruction]
        }

  @type player_id :: any
  @type move :: {:outbid, bid()} | :calza | :dudo
  @type instruction ::
          {:notify_player, visibility, player_id, player_instruction}
  @type bid :: {:count, :die}

  @type player_instruction ::
          :move
          | {:remove_die, player_id}
          | {:add_die, player_id}
          | :reveal_hands
          | {:new_bid, bid()}
          | :unauthorized_move
          | :illegal_bid
          | {:new_hand, DiceHand.t()}

  @type visibility :: :private | :public

  def start(player_ids, max_dice) do
    %Round{
      current_player_id: hd(player_ids),
      all_players: player_ids,
      remaining_players: player_ids,
      hands: [],
      max_dice: max_dice,
      instructions: []
    }
    |> start_new_round(hd(player_ids))
    |> instructions_and_state()
  end

  defp start_new_round(round, next_player) do
    round = %Round{
      round
      | current_player_id: next_player,
        hands:
          Enum.map(round.remaining_players, fn p -> %{player_id: p, hand: DiceHand.new(5)} end),
        current_bid: {0, 0}
    }

    Enum.reduce(
      round.remaining_players,
      round,
      &notify_player(
        &2,
        :private,
        &1,
        {:new_hand, Enum.find(round.hands, fn x -> x.player_id == &1 end).hand}
      )
    )
  end

  def move(%Round{current_player_id: player_id} = round, player_id, move) do
    %Round{round | instructions: []}
    |> handle_move(move)
  end

  def move(round, player_id, _move) do
    %Round{round | instructions: []}
    |> notify_player(:public, player_id, :unauthorized_move)
  end

  defp handle_move(round, {:outbid, bid}) do
    case outbid(round, bid) do
      {:ok, round} ->
        round
        |> notify_player(:public, round.current_player_id, {:new_bid, bid})
        |> find_next_player()
        |> notify_player(:public, round.current_player_id, :move)
        |> instructions_and_state()

      {:error, round} ->
        round
        |> notify_player(:public, round.current_player_id, :illegal_bid)
        |> instructions_and_state()
    end
  end

  defp handle_move(round, :calza) do
  end

  defp handle_move(round, :dudo) do
  end

  defp outbid(%Round{current_bid: {0, 0}} = round, {_new_count, 1}), do: {:error, round}

  defp outbid(%Round{current_bid: {current_count, 1}} = round, {new_count, 1}) do
    case new_count > current_count do
      true ->
        {:ok, %Round{round | instructions: [], current_bid: {new_count, 1}}}

      _ ->
        {:error, round}
    end
  end

  defp outbid(%Round{current_bid: {current_count, _current_die}} = round, {new_count, 1}) do
    case new_count >= ceil(current_count / 2) do
      true ->
        {:ok, %Round{round | instructions: [], current_bid: {new_count, 1}}}

      _ ->
        {:error, round}
    end
  end

  defp outbid(%Round{current_bid: {current_count, 1}} = round, {new_count, new_die}) do
    case new_count >= current_count * 2 + 1 do
      true ->
        {:ok, %Round{round | instructions: [], current_bid: {new_count, new_die}}}

      _ ->
        {:error, round}
    end
  end

  defp outbid(%Round{current_bid: {current_count, current_die}} = round, {new_count, new_die}) do
    case (new_count >= current_count && new_die > current_die) ||
           (new_count > current_count && new_die >= current_die) do
      true ->
        {:ok, %Round{round | instructions: [], current_bid: {new_count, new_die}}}

      _ ->
        {:error, round}
    end
  end

  defp find_next_player(round) do
    current_player_index =
      Enum.find_index(round.remaining_players, fn id -> id == round.current_player_id end)

    next_player = Enum.at(round.remaining_players, current_player_index + 1)

    next_player =
      case next_player == nil do
        true ->
          [next_player | _] = round.remaining_players
          next_player

        false ->
          next_player
      end

    %Round{round | current_player_id: next_player}
  end

  defp notify_player(round, visibility, player_id, data) do
    %Round{
      round
      | instructions: [{:notify_player, visibility, player_id, data} | round.instructions]
    }
  end

  defp instructions_and_state(round) do
    round
    |> tell_current_player_to_move()
    |> take_instructions()
  end

  defp tell_current_player_to_move(%Round{current_player_id: nil} = round), do: round

  defp tell_current_player_to_move(round),
    do: notify_player(round, :public, round.current_player_id, :move)

  defp take_instructions(round),
    do: {Enum.reverse(round.instructions), %Round{round | instructions: []}}
end
