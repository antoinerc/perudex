defmodule Perudo.Round do
  alias __MODULE__

  alias Perudo.DiceHand

  defstruct [
    :current_player_id,
    :all_players,
    :remaining_players,
    :current_bid,
    :hands,
    :instructions
  ]

  @type t :: %Round{
          current_player_id: player_id,
          all_players: [player_id],
          current_bid: bid(),
          remaining_players: [player_id],
          hands: [%{player_id: player_id, hand: DiceHand.t()}],
          instructions: [instruction]
        }

  @type player_id :: any
  @type move :: {:outbid, bid()} | :calza | :dudo
  @type instruction ::
          {:notify_player, visibility, player_id, player_instruction}
  @type bid :: %{count: integer(), die: DiceHand.die()}

  @type player_instruction ::
          :move
          | {:remove_die, player_id}
          | {:add_die, player_id}
          | :reveal_hands
          | {:new_bid, bid()}
          | :unauthorized_move
          | {:new_hand, DiceHand.t()}

  @type visibility :: :private | :public

  def start(player_ids) do
    r = %Round{
      current_player_id: Enum.random(player_ids),
      all_players: player_ids,
      remaining_players: player_ids,
      current_bid: {0, 0},
      hands: [],
      instructions: []
    }

    start_new_round(r, r.current_player_id)
  end

  defp start_new_round(round, next_player) do
    round = %Round{
      round
      | current_player_id: next_player,
        hands:
          Enum.map(round.remaining_players, fn p -> %{player_id: p, hand: DiceHand.new(5)} end),
        current_bid: nil
    }

    Enum.reduce(
      round.remaining_players,
      round,
      &notify_player(
        &2,
        :private,
        &1,
        {:new_hand, Enum.find(round.hands, fn x -> x.id == &2 end).hand}
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

      {:error, round} ->
        notify_player(round, :public, round.current_player_id, :unauthorized_move)
    end
  end

  defp handle_move(round, :calza) do
  end

  defp handle_move(round, :dudo) do
  end

  defp outbid(%Round{current_bid: current_bid} = round, bid) do
    # case 1 -> ncount > or ndie > or (die == 1 and ncount >= count/2)
    case bid.count <= current_bid.count && bid.die <= current_bid.die and bid.die != 1 do
      true ->
        {:error, round}

      _ ->
        {:ok, %Round{round | instructions: [], current_bid: bid}}
    end
  end

  defp find_next_player(round) do
    current_player_index =
      Enum.find_index(round.remaining_players, fn x -> x.id == round.current_player_id end)

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
end