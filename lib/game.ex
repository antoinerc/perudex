defmodule Perudex.Game do
  @moduledoc """
  Provides functions to manipulate a game of Perudex.
  """
  alias __MODULE__

  alias Perudex.Hand

  defstruct [
    :current_player_id,
    :all_players,
    :current_bid,
    :max_dice,
    :instructions,
    players_hands: %{},
    phase: :normal
  ]

  @opaque t :: %Game{
            phase: game_phase,
            current_player_id: player_id,
            all_players: [player_id],
            current_bid: bid,
            players_hands: %{player_id: Hand.t()},
            max_dice: integer(),
            instructions: [instruction]
          }

  @type player_id :: any
  @type move :: {:outbid, bid} | :calza | :dudo
  @type game_phase :: :normal | :palifico
  @type instruction :: {:notify_player, player_id, player_instruction}
  @type bid :: {:count, :die}
  @type move_result :: {:outbid, bid} | {:calza, boolean} | {:dudo, boolean}

  @type player_instruction ::
          {:move, Hand.t()}
          | {:reveal_players_hands, %{player_id() => Hand.t()}, {integer, integer}}
          | {:last_move, player_id, move_result}
          | :unauthorized_move
          | :invalid_bid
          | :illegal_move
          | {:new_hand, Hand.t()}
          | {:winner, player_id}
          | {:loser, player_id}
          | {:game_started, [player_id]}

  @doc """
  Initialize a game of Perudo with `players_ids` and specified `max_dice` a player can hold.

  Returns a tuple containing a list of `Perudex.Game.player_instruction()` and a `Perudex.Game` struct.

  ## Examples
      iex>
      :rand.seed(:exsplus, {101, 102, 103})
      Perudex.Game.start([1, 2], 5)
      {[
        {:notify_player, 1, {:game_started, [1, 2]}},
        {:notify_player, 2, {:game_started, [1, 2]}},
        {:notify_player, 1, {:new_hand, %Perudex.Hand{dice: [5, 5, 2, 6, 4], remaining_dice: 5}}},
        {:notify_player, 2, {:new_hand, %Perudex.Hand{dice: [1, 3, 6, 4, 2], remaining_dice: 5}}},
        {:notify_player, 1, {:move, %Perudex.Hand{dice: [5, 5, 2, 6, 4]}}
      ],
      %Perudex.Game{
        all_players: [1, 2],
        current_bid: {0, 0},
        current_player_id: 1,
        instructions: [],
        max_dice: 5,
        players_hands: %{1 => hand: %Perudex.Hand{dice: [5, 5, 2, 6, 4], remaining_dice: 5}, 2 => %Perudex.Hand{dice: [1, 3, 6, 4, 2], remaining_dice: 5}}
      }}
  """
  @spec start([player_id], integer) :: {[player_instruction], Perudex.Game.t()}
  def start(player_ids, max_dice) do
    %Game{
      current_player_id: hd(player_ids),
      all_players: player_ids,
      players_hands:
        Map.new(player_ids, fn id -> {id, Hand.new(%Hand{remaining_dice: max_dice})} end),
      max_dice: max_dice,
      instructions: []
    }
    |> notify_players({:game_started, player_ids})
    |> start_round()
    |> instructions_and_state()
  end

  @doc """
  Play a Perudo `move` on the current game.

  A move can either be an outbid, a calza (exactly the same amount of dice as the previous bid) or a dudo (bid is too ambitious).
  ## Examples
      iex> Perudex.Game.play_move(
      ...> %Perudex.Game{
      ...>    all_players: [1, 2],
      ...>    current_bid: {2, 3},
      ...>    current_player_id: 2,
      ...>    instructions: [],
      ...>    max_dice: 5,
      ...>    players_hands: %{1 => %Perudex.Hand{dice: [2, 4, 2, 5, 6], remaining_dice: 5}, 2 => %Perudex.Hand{dice: [1, 3, 4, 4, 5], remaining_dice: 5}}},
      ...>  1,
      ...>  {:outbid, {2, 3}})

      {[
        {:notify_player, 1, {:last_move, 1, {:outbid, {2, 3}}}},
        {:notify_player, 2, {:last_move, 1, {:outbid, {2, 3}}}},
        {:notify_player, 2, :move}
      ],
      %Perudex.Game{
        all_players: [1, 2],
        current_bid: {2, 3},
        current_player_id: 2,
        instructions: [],
        max_dice: 5,
        players_hands: %{1 => %Perudex.Hand{dice: [2, 4, 2, 5, 6], remaining_dice: 5}, 2 => %Perudex.Hand{dice: [1, 3, 4, 4, 5], remaining_dice: 5}}
      }}
  """
  @spec play_move(t, player_id, move) :: {[instruction], t()}
  def play_move(%Game{current_player_id: player_id} = game, player_id, move),
    do: handle_move(%Game{game | instructions: []}, move)

  def play_move(game, player_id, _move) do
    %Game{game | instructions: []}
    |> notify_player(player_id, :unauthorized_move)
    |> take_instructions()
  end

  defp handle_move(game, {:outbid, bid} = move) do
    case outbid(game, bid) do
      {:ok, game} ->
        game
        |> notify_players({:last_move, game.current_player_id, move})
        |> find_next_player()
        |> instructions_and_state()

      {:error, game} ->
        game
        |> notify_player(game.current_player_id, :invalid_bid)
        |> take_instructions()
    end
  end

  defp handle_move(%Game{current_player_id: move_initiator} = game, :calza) do
    case calza(game) do
      {:ok, game, success_status} ->
        end_round(game, {:last_move, move_initiator, {:calza, success_status}})

      {:error, game} ->
        game
        |> notify_player(game.current_player_id, :illegal_move)
        |> take_instructions()
    end
  end

  defp handle_move(%Game{current_player_id: move_initiator} = game, :dudo) do
    case dudo(game) do
      {:ok, game, success_status} ->
        end_round(game, {:last_move, move_initiator, {:dudo, success_status}})

      {:error, game} ->
        game
        |> notify_player(game.current_player_id, :illegal_move)
        |> take_instructions()
    end
  end

  defp dudo(%Game{current_bid: {0, 0}} = game), do: {:error, game}

  defp dudo(
         %Game{
           players_hands: players_hands,
           current_bid: {current_count, _}
         } = game
       ) do
    current_count_frequency = get_current_die_frequency(game)
    round_loser = find_dudo_loser(game, current_count_frequency)

    {:ok,
     %Game{
       game
       | current_player_id: round_loser,
         players_hands: %{
           players_hands
           | round_loser => Hand.take(players_hands[round_loser])
         }
     }, current_count_frequency < current_count}
  end

  defp calza(%Game{current_bid: {0, 0}} = game), do: {:error, game}

  defp calza(
         %Game{
           players_hands: players_hands,
           current_bid: {current_count, _},
           current_player_id: current_player
         } = game
       ) do
    current_count_frequency = get_current_die_frequency(game)

    updated_hand =
      if current_count_frequency == current_count do
        Hand.add(players_hands[current_player])
      else
        Hand.take(players_hands[current_player])
      end

    {:ok,
     %Game{
       game
       | players_hands: %{
           players_hands
           | current_player => updated_hand
         }
     }, current_count_frequency == current_count}
  end

  defp outbid(game, {count, dice}) when not is_integer(dice) or not is_integer(count),
    do: {:error, game}

  defp outbid(%Game{current_bid: {0, 0}} = game, {_new_count, 1}), do: {:error, game}
  defp outbid(%Game{current_bid: {count, dice}} = game, {count, dice}), do: {:error, game}
  defp outbid(game, {_, dice}) when dice > 6, do: {:error, game}
  defp outbid(game, {count, dice}) when dice < 1 or count < 1, do: {:error, game}

  defp outbid(%Game{current_bid: {current_count, 1}} = game, {new_count, 1})
       when new_count <= current_count,
       do: {:error, game}

  defp outbid(%Game{current_bid: {current_count, _}} = game, {new_count, 1})
       when new_count < ceil(current_count / 2),
       do: {:error, game}

  defp outbid(%Game{current_bid: {_current_count, _}} = game, {new_count, 1}),
    do: {:ok, %Game{game | instructions: [], current_bid: {new_count, 1}}}

  defp outbid(%Game{current_bid: {current_count, 1}} = game, {new_count, _})
       when new_count < current_count * 2 + 1,
       do: {:error, game}

  defp outbid(%Game{current_bid: {_current_count, 1}} = game, {new_count, new_dice}),
    do: {:ok, %Game{game | instructions: [], current_bid: {new_count, new_dice}}}

  defp outbid(%Game{current_bid: {current_count, current_dice}} = game, {new_count, new_dice})
       when (new_count < current_count or new_dice <= current_dice) and
              (new_count <= current_count or new_dice < current_dice),
       do: {:error, game}

  defp outbid(%Game{} = game, {new_count, new_dice}),
    do: {:ok, %Game{game | instructions: [], current_bid: {new_count, new_dice}}}

  defp find_dudo_loser(
         %Game{current_player_id: current_player, current_bid: {current_count, _}} = game,
         current_count_frequency
       ) do
    previous_player = find_previous_player(game)

    if current_count_frequency < current_count do
      previous_player
    else
      current_player
    end
  end

  defp end_round(game, move_result) do
    game
    |> notify_players(move_result)
    |> reveal_players_hands()
    |> check_for_loser()
    |> start_round()
    |> instructions_and_state()
  end

  defp reveal_players_hands(%Game{players_hands: hands, current_bid: {_, die}} = game),
    do:
      notify_players(game, {:reveal_players_hands, hands, {get_current_die_frequency(game), die}})

  defp find_next_player(%Game{players_hands: players} = game) when map_size(players) == 1 do
    {id, _} = Enum.at(players, 0)
    %Game{game | current_player_id: id}
  end

  defp find_next_player(game) do
    current_player_index =
      Enum.find_index(game.players_hands, fn {id, _} -> id == game.current_player_id end)

    {next_player_id, _} =
      Enum.at(game.players_hands, current_player_index + 1, Enum.at(game.players_hands, 0))

    %Game{game | current_player_id: next_player_id}
  end

  defp find_previous_player(game) do
    current_player_index =
      Enum.find_index(game.players_hands, fn {id, _} -> id == game.current_player_id end)

    {id, _} =
      Enum.at(
        game.players_hands,
        current_player_index - 1,
        Enum.at(game.players_hands, Enum.count(game.players_hands) - 1)
      )

    id
  end

  defp check_for_loser(%Game{} = game) do
    loser = Enum.find(game.players_hands, fn {_, hand} -> hand.remaining_dice == 0 end)

    case loser do
      nil ->
        game

      {loser_id, _} ->
        game
        |> find_next_player()
        |> eliminate_player(loser_id)
        |> notify_players({:loser, loser_id})
    end
  end

  defp eliminate_player(%Game{} = game, loser_id) do
    %Game{
      game
      | players_hands: Map.delete(game.players_hands, loser_id)
    }
  end

  defp get_current_die_frequency(%Game{
         players_hands: players_hands,
         current_bid: {_, 1}
       }) do
    dice_frequencies = get_dice_frequencies(players_hands)

    dice_frequencies =
      if dice_frequencies[1] == nil,
        do: Map.put(dice_frequencies, 1, 0),
        else: dice_frequencies

    dice_frequencies[1]
  end

  defp get_current_die_frequency(%Game{
         players_hands: players_hands,
         current_bid: {_, current_die}
       }) do
    dice_frequencies = get_dice_frequencies(players_hands)

    dice_frequencies =
      if dice_frequencies[current_die] == nil,
        do: Map.put(dice_frequencies, current_die, 0),
        else: dice_frequencies

    dice_frequencies =
      if dice_frequencies[1] == nil,
        do: Map.put(dice_frequencies, 1, 0),
        else: dice_frequencies

    dice_frequencies[current_die] + dice_frequencies[1]
  end

  defp get_dice_frequencies(players_hands) do
    players_hands
    |> Enum.flat_map(fn {_, hand} -> hand.dice end)
    |> Enum.frequencies()
  end

  defp notify_player(game, player_id, data) do
    %Game{
      game
      | instructions: [{:notify_player, player_id, data} | game.instructions]
    }
  end

  defp notify_players(game, data) do
    Enum.reduce(
      game.all_players,
      game,
      &notify_player(
        &2,
        &1,
        data
      )
    )
  end

  defp instructions_and_state(game) do
    game
    |> tell_current_player_to_move()
    |> take_instructions()
  end

  defp tell_current_player_to_move(%Game{current_player_id: nil} = game), do: game

  defp tell_current_player_to_move(%Game{current_player_id: id, players_hands: hands} = game),
    do: notify_player(game, id, {:move, hands[id]})

  defp start_round(%Game{players_hands: players} = game) when map_size(players) == 1 do
    game = %Game{game | current_player_id: nil, players_hands: %{}, current_bid: nil}
    {winner, _} = Enum.at(players, 0)
    notify_players(game, {:winner, winner})
  end

  defp start_round(game) do
    game = %Game{
      game
      | players_hands: Map.new(game.players_hands, fn {id, hand} -> {id, Hand.new(hand)} end),
        current_bid: {0, 0}
    }

    Enum.reduce(
      game.players_hands,
      game,
      fn {id, _}, game -> notify_player(game, id, {:new_hand, game.players_hands[id]}) end
    )
  end

  defp take_instructions(game),
    do: {Enum.reverse(game.instructions), %Game{game | instructions: []}}
end
