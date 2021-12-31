defmodule Perudo.Game do
  @moduledoc """
  Provides functions to manipulate a game of Perudo.
  """
  alias __MODULE__

  alias Perudo.Hand

  defstruct [
    :current_player_id,
    :all_players,
    :remaining_players,
    :current_bid,
    :players_hands,
    :max_dice,
    :instructions
  ]

  @type t :: %Game{
          current_player_id: player_id,
          all_players: [player_id],
          current_bid: bid(),
          remaining_players: [player_id],
          players_hands: [%{player_id: player_id, hand: Hand.t()}],
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
          | {:reveal_players_hands, [Hand.t()]}
          | {:new_bid, bid()}
          | :unauthorized_move
          | :illegal_bid
          | :illegal_move
          | {:new_hand, Hand.t()}
          | :successful_calza
          | :unsuccessful_calza
          | :winner
          | :loser

  @type visibility :: :private | :public

  def start(player_ids, max_dice) do
    %Game{
      current_player_id: hd(player_ids),
      all_players: player_ids,
      remaining_players: player_ids,
      players_hands: [],
      max_dice: max_dice,
      instructions: []
    }
    |> initialize_players_hands()
    |> start_new_game(hd(player_ids))
    |> instructions_and_state()
  end

  defp initialize_players_hands(game) do
    %Game{
      game
      | players_hands:
          Enum.map(game.remaining_players, fn p ->
            %{player_id: p, hand: Hand.new(game.max_dice)}
          end)
    }
  end

  defp start_new_game(%Game{remaining_players: [winner]} = game, _) do
    %Game{game | current_player_id: nil, players_hands: [], current_bid: nil}
    |> notify_player(:public, winner, :winner)
  end

  defp start_new_game(game, next_player) do
    game = %Game{
      game
      | current_player_id: next_player,
        players_hands:
          Enum.map(game.remaining_players, fn p ->
            %{
              player_id: p,
              hand: Hand.new(Enum.find(game.players_hands, fn x -> x.player_id == p end).hand)
            }
          end),
        current_bid: {0, 0}
    }

    Enum.reduce(
      game.remaining_players,
      game,
      &notify_player(
        &2,
        :private,
        &1,
        {:new_hand, Enum.find(game.players_hands, fn x -> x.player_id == &1 end).hand}
      )
    )
  end

  def move(%Game{current_player_id: player_id} = game, player_id, move) do
    %Game{game | instructions: []}
    |> handle_move(move)
  end

  def move(game, player_id, _move) do
    %Game{game | instructions: []}
    |> notify_player(:public, player_id, :unauthorized_move)
    |> instructions_and_state()
  end

  defp handle_move(game, {:outbid, bid}) do
    case outbid(game, bid) do
      {:ok, game} ->
        game
        |> notify_player(:public, game.current_player_id, {:new_bid, bid})
        |> find_next_player()
        |> instructions_and_state()

      {:error, game} ->
        game
        |> notify_player(:public, game.current_player_id, :illegal_bid)
        |> instructions_and_state()
    end
  end

  defp handle_move(game, :calza) do
    game = reveal_players_hands(game)

    case calza(game) do
      {:ok, game, succes_status} ->
        game
        |> check_for_loser()
        |> start_new_game(game.current_player_id)
        |> notify_player(:public, game.current_player_id, succes_status)
        |> instructions_and_state()

      {:error, game} ->
        game
        |> notify_player(:public, game.current_player_id, :illegal_move)
        |> instructions_and_state()
    end
  end

  defp handle_move(game, :dudo) do
    game = reveal_players_hands(game)

    case dudo(game) do
      {:ok, game, success_status} ->
        game
        |> check_for_loser()
        |> start_new_game(game.current_player_id)
        |> notify_player(:public, game.current_player_id, success_status)
        |> instructions_and_state()

      {:error, game} ->
        game
        |> notify_player(:public, game.current_player_id, :illegal_move)
        |> instructions_and_state()
    end
  end

  defp dudo(%Game{current_bid: {0, 0}} = game), do: {:error, game}

  defp dudo(
         %Game{
           players_hands: players_hands,
           current_bid: {current_count, current_die},
           current_player_id: current_player
         } = game
       ) do
    current_count_frequency = get_current_die_frequency(players_hands, current_die)
    previous_player = find_previous_player(game)

    case current_count_frequency < current_count do
      true ->
        {:ok,
         %Game{
           game
           | current_player_id: previous_player,
             players_hands:
               Enum.map(players_hands, fn hand ->
                 if hand.player_id == previous_player,
                   do: %{hand | hand: Hand.take(hand.hand)},
                   else: hand
               end)
         }, :successful_dudo}

      _ ->
        {:ok,
         %Game{
           game
           | players_hands:
               Enum.map(players_hands, fn hand ->
                 if hand.player_id == current_player,
                   do: %{hand | hand: Hand.take(hand.hand)},
                   else: hand
               end)
         }, :unsuccessful_dudo}
    end
  end

  defp calza(%Game{current_bid: {0, 0}} = game), do: {:error, game}

  defp calza(
         %Game{
           players_hands: players_hands,
           current_bid: {current_count, current_die},
           current_player_id: current_player
         } = game
       ) do
    current_count_frequency = get_current_die_frequency(players_hands, current_die)

    case current_count_frequency == current_count do
      true ->
        {:ok,
         %Game{
           game
           | players_hands:
               Enum.map(players_hands, fn player_hand ->
                 if player_hand.player_id == current_player,
                   do: %{player_hand | hand: Hand.add(player_hand.hand)},
                   else: player_hand
               end)
         }, :successful_calza}

      _ ->
        {:ok,
         %Game{
           game
           | players_hands:
               Enum.map(players_hands, fn player_hand ->
                 if player_hand.player_id == current_player,
                   do: %{player_hand | hand: Hand.take(player_hand.hand)},
                   else: player_hand
               end)
         }, :unsuccessful_calza}
    end
  end

  defp outbid(%Game{current_bid: {0, 0}} = game, {_new_count, 1}), do: {:error, game}

  defp outbid(
         %Game{current_bid: {current_count, current_die}} = game,
         {current_count, current_die}
       ) do
    {:error, game}
  end

  defp outbid(game, {_, 0}) do
    {:error, game}
  end

  defp outbid(game, {0, _}) do
    {:error, game}
  end

  defp outbid(%Game{current_bid: {current_count, 1}} = game, {new_count, 1}) do
    case new_count > current_count do
      true ->
        {:ok, %Game{game | instructions: [], current_bid: {new_count, 1}}}

      _ ->
        {:error, game}
    end
  end

  defp outbid(%Game{current_bid: {current_count, _current_die}} = game, {new_count, 1}) do
    case new_count >= ceil(current_count / 2) do
      true ->
        {:ok, %Game{game | instructions: [], current_bid: {new_count, 1}}}

      _ ->
        {:error, game}
    end
  end

  defp outbid(%Game{current_bid: {current_count, 1}} = game, {new_count, new_die}) do
    case new_count >= current_count * 2 + 1 do
      true ->
        {:ok, %Game{game | instructions: [], current_bid: {new_count, new_die}}}

      _ ->
        {:error, game}
    end
  end

  defp outbid(%Game{current_bid: {current_count, current_die}} = game, {new_count, new_die}) do
    case (new_count >= current_count && new_die > current_die) ||
           (new_count > current_count && new_die >= current_die) do
      true ->
        {:ok, %Game{game | instructions: [], current_bid: {new_count, new_die}}}

      _ ->
        {:error, game}
    end
  end

  defp reveal_players_hands(game),
    do: notify_player(game, :public, 1, {:reveal_players_hands, game.players_hands})

  defp find_next_player(%Game{remaining_players: [winner]} = game) do
    %Game{game | current_player_id: winner}
  end

  defp find_next_player(game) do
    current_player_index =
      Enum.find_index(game.remaining_players, fn id -> id == game.current_player_id end)

    next_player =
      Enum.at(game.remaining_players, current_player_index + 1, hd(game.remaining_players))

    %Game{game | current_player_id: next_player}
  end

  defp find_previous_player(game) do
    current_player_index =
      Enum.find_index(game.remaining_players, fn id -> id == game.current_player_id end)

    Enum.at(game.remaining_players, current_player_index - 1, hd(game.remaining_players))
  end

  defp check_for_loser(%Game{} = game) do
    loser = Enum.find(game.players_hands, fn hand -> hand.hand.remaining_dice == 0 end)

    case loser != nil do
      true ->
        %Game{
          game
          | remaining_players:
              Enum.filter(game.remaining_players, fn player -> player != loser.player_id end)
        }
        |> find_next_player()
        |> notify_player(:public, loser.player_id, :loser)

      false ->
        game
    end
  end

  defp get_current_die_frequency(players_hands, current_die) do
    dice_frequencies = get_dice_frequencies(players_hands)
    dice_frequencies[current_die]
  end

  defp get_dice_frequencies(players_hands) do
    players_hands
    |> Enum.flat_map(fn %{hand: hand} -> hand.dice end)
    |> Enum.frequencies()
  end

  defp notify_player(game, visibility, player_id, data) do
    %Game{
      game
      | instructions: [{:notify_player, visibility, player_id, data} | game.instructions]
    }
  end

  defp instructions_and_state(game) do
    game
    |> tell_current_player_to_move()
    |> take_instructions()
  end

  defp tell_current_player_to_move(%Game{current_player_id: nil} = game), do: game

  defp tell_current_player_to_move(game),
    do: notify_player(game, :public, game.current_player_id, :move)

  defp take_instructions(game),
    do: {Enum.reverse(game.instructions), %Game{game | instructions: []}}
end
