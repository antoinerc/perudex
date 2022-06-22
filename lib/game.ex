defmodule Perudex.Game do
  @moduledoc """
  Provides functions to manipulate a game of Perudex.
  """
  alias __MODULE__

  alias Perudex.Hand
  alias Perudex.Bid

  defstruct [
    :current_player_id,
    :all_players,
    :current_bid,
    :max_dice,
    :instructions,
    players_hands: %{},
    phase: :normal,
    next_phase: nil
  ]

  @opaque t :: %Game{
            phase: game_phase,
            next_phase: game_phase,
            current_player_id: player_id,
            all_players: [player_id],
            current_bid: Bid.t(),
            players_hands: %{player_id: Hand.t()},
            max_dice: integer(),
            instructions: [instruction]
          }

  @type player_id :: any
  @type move :: {:outbid, Bid.t()} | :calza | :dudo
  @type game_phase :: :normal | :palifico
  @type instruction :: {:notify_player, player_id, player_instruction}
  @type move_result :: {:outbid, Bid.t()} | {:calza, boolean} | {:dudo, boolean}

  @type player_instruction ::
          {:move, Hand.t()}
          | {:announce_next_player, player_id}
          | {:reveal_players_hands, %{player_id() => Hand.t()}, {integer, integer}}
          | {:last_move, player_id, move_result}
          | :unauthorized_move
          | :invalid_bid
          | :illegal_move
          | {:new_hand, Hand.t()}
          | {:winner, player_id}
          | {:loser, player_id}
          | {:game_started, [player_id]}
          | {:phase_change, game_phase}

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
        current_bid: %Perudex.Bid{count: 0, value: 0},
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
      ...>    current_bid: %Perudex.Bid{count: 2, value: 3},
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
        current_bid: %Perudex.Bid{count: 2, value: 3},
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

  defp handle_move(%Game{} = game, {:outbid, bid} = move) do
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

  defp dudo(%Game{current_bid: %Bid{count: 0, value: 0}} = game), do: {:error, game}

  defp dudo(
         %Game{
           players_hands: players_hands,
           current_bid: %Bid{count: current_count}
         } = game
       ) do
    current_count_frequency = get_current_die_frequency(game)
    round_loser = find_dudo_loser(game, current_count_frequency)
    hand = players_hands[round_loser]
    updated_hand = Hand.take(hand)

    next_phase =
      if updated_hand.has_palificoed and not hand.has_palificoed do
        :palifico
      else
        :normal
      end

    {:ok,
     %Game{
       game
       | current_player_id: round_loser,
         players_hands: %{
           players_hands
           | round_loser => updated_hand
         },
         next_phase: next_phase
     }, current_count_frequency < current_count}
  end

  defp calza(%Game{current_bid: %Bid{count: 0, value: 0}} = game), do: {:error, game}

  defp calza(
         %Game{
           players_hands: players_hands,
           current_bid: %Bid{count: current_count},
           current_player_id: current_player
         } = game
       ) do
    current_count_frequency = get_current_die_frequency(game)
    hand = players_hands[current_player]

    updated_hand =
      if current_count_frequency == current_count do
        Hand.add(hand)
      else
        Hand.take(hand)
      end

    next_phase =
      if updated_hand.has_palificoed and not hand.has_palificoed,
        do: :palifico,
        else: :normal

    {:ok,
     %Game{
       game
       | players_hands: %{players_hands | current_player => updated_hand},
         next_phase: next_phase
     }, current_count_frequency == current_count}
  end

  defp outbid(game, {count, dice}) when not is_integer(dice) or not is_integer(count),
    do: {:error, game}

  defp outbid(%Game{current_bid: current_bid, phase: phase} = game, {count, die}) do
    if Bid.valid?(%Bid{count: count, value: die}, current_bid, phase) do
      {:ok, %Game{game | instructions: [], current_bid: %Bid{count: count, value: die}}}
    else
      {:error, game}
    end
  end

  defp find_dudo_loser(
         %Game{current_player_id: current_player, current_bid: %Bid{count: current_count}} = game,
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

  defp reveal_players_hands(%Game{players_hands: hands, current_bid: %Bid{value: die}} = game),
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
         current_bid: %Bid{value: current_die},
         phase: :normal
       }) do
    Enum.reduce(players_hands, 0, fn {_, dice}, acc ->
      acc + Hand.count_pip_frequency(dice, current_die) + Hand.count_pip_frequency(dice, 1)
    end)
  end

  defp get_current_die_frequency(%Game{
         players_hands: players_hands,
         current_bid: %Bid{value: current_die},
         phase: :palifico
       }) do
    Enum.reduce(players_hands, 0, fn {_, dice}, acc ->
      acc + Hand.count_pip_frequency(dice, current_die)
    end)
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

  defp notify_players(game, players, data) do
    Enum.reduce(
      players,
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
    |> announce_next_player()
    |> take_instructions()
  end

  defp tell_current_player_to_move(%Game{current_player_id: nil} = game), do: game

  defp tell_current_player_to_move(%Game{current_player_id: id, players_hands: hands} = game),
    do: notify_player(game, id, {:move, hands[id]})

  defp announce_next_player(%Game{current_player_id: nil} = game), do: game

  defp announce_next_player(%Game{current_player_id: id, all_players: players} = game),
    do:
      notify_players(
        game,
        Enum.reject(players, fn player -> player == id end),
        {:next_player, id}
      )

  defp handle_phase_change(%Game{phase: _current_phase, next_phase: nil} = game), do: game

  defp handle_phase_change(%Game{phase: phase, next_phase: phase} = game), do: game

  defp handle_phase_change(%Game{next_phase: next_phase} = game),
    do:
      notify_players(
        %Game{game | phase: next_phase, next_phase: nil},
        {:phase_change, next_phase}
      )

  defp start_round(%Game{players_hands: players} = game) when map_size(players) == 1 do
    game = %Game{game | current_player_id: nil, players_hands: %{}, current_bid: nil}
    {winner, _} = Enum.at(players, 0)
    notify_players(game, {:winner, winner})
  end

  defp start_round(game) do
    game = %Game{
      game
      | players_hands: Map.new(game.players_hands, fn {id, hand} -> {id, Hand.new(hand)} end),
        current_bid: %Bid{count: 0, value: 0}
    }

    game = handle_phase_change(game)

    Enum.reduce(
      game.players_hands,
      game,
      fn {id, _}, game -> notify_player(game, id, {:new_hand, game.players_hands[id]}) end
    )
  end

  defp take_instructions(game),
    do: {Enum.reverse(game.instructions), %Game{game | instructions: []}}
end
