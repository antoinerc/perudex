defmodule GameTest do
  use ExUnit.Case
  doctest Perudex.Game

  alias Perudex.Game
  alias Perudex.Hand

  defmacrop notify_player_instruction(player_id, data) do
    quote do
      {:notify_player, unquote(player_id), unquote(data)}
    end
  end

  test "initial game" do
    max_dice = 5
    players = [1, 2]

    assert {notifications, r} = Game.start(players, max_dice)

    [notification | rest] = notifications
    notifications = rest
    assert {:notify_player, 1, {:game_started, ^players}} = notification

    [notification | rest] = notifications
    notifications = rest
    assert {:notify_player, 2, {:game_started, ^players}} = notification

    [notification | rest] = notifications
    notifications = rest
    assert {:notify_player, 1, {:new_hand, hand}} = notification
    [notification | rest] = notifications
    notifications = rest
    assert {:notify_player, 2, {:new_hand, _}} = notification
    [notification | _] = notifications

    assert {:notify_player, r.current_player_id, {:move, hand}} ==
             notification

    assert %Game{
             instructions: [],
             max_dice: ^max_dice,
             all_players: players,
             players_hands: %{},
             current_bid: {0, 0}
           } = r
  end

  test "unauthorized move" do
    {_, initial_game} = Game.start([1, 2], 5)
    assert %Game{current_player_id: 1} = initial_game

    assert {_, new_game} = Game.play_move(initial_game, 1, {:outbid, {2, 2}})
    assert {instructions, new_game} = Game.play_move(new_game, 1, {:outbid, {3, 3}})
    assert %Game{current_player_id: 2, current_bid: {2, 2}} = new_game
    assert Enum.member?(instructions, notify_player_instruction(1, :unauthorized_move))
  end

  test "outbid move to next player" do
    {_, initial_game} = Game.start([1, 2], 5)
    assert %Game{current_player_id: 1} = initial_game

    assert {instructions, new_game} = Game.play_move(initial_game, 1, {:outbid, {2, 2}})
    assert %Game{current_player_id: 2, current_bid: {2, 2}, players_hands: hands} = new_game

    assert Enum.member?(
             instructions,
             notify_player_instruction(
               2,
               {:move, hands[2]}
             )
           )

    assert {instructions, new_game} = Game.play_move(new_game, 2, {:outbid, {3, 3}})

    assert Enum.member?(
             instructions,
             notify_player_instruction(
               1,
               {:move, hands[1]}
             )
           )

    assert %Game{current_player_id: 1, current_bid: {3, 3}} = new_game

    assert {instructions, new_game} = Game.play_move(new_game, 1, {:outbid, {4, 4}})
    assert %Game{current_player_id: 2, current_bid: {4, 4}, players_hands: hands} = new_game

    assert Enum.member?(
             instructions,
             notify_player_instruction(
               2,
               {:move, hands[2]}
             )
           )
  end

  test "outbid does not move to next player if bid illegal" do
    {_, game} = Game.start([1, 2], 5)
    assert %Game{current_player_id: 1, current_bid: {0, 0}} = game
    assert {_, game} = Game.play_move(game, 1, {:outbid, {2, 2}})
    assert %Game{current_player_id: 2, current_bid: {2, 2}} = game

    assert {instructions, game} = Game.play_move(game, 2, {:outbid, {-1, 2}})
    assert %Game{current_player_id: 2, current_bid: {2, 2}} = game
    assert Enum.member?(instructions, notify_player_instruction(2, :invalid_bid))

    assert {instructions, game} = Game.play_move(game, 2, {:outbid, {4, -5}})
    assert %Game{current_player_id: 2, current_bid: {2, 2}} = game
    assert Enum.member?(instructions, notify_player_instruction(2, :invalid_bid))

    assert {instructions, game} = Game.play_move(game, 2, {:outbid, {2, 2}})
    assert %Game{current_player_id: 2, current_bid: {2, 2}} = game
    assert Enum.member?(instructions, notify_player_instruction(2, :invalid_bid))

    assert {instructions, game} = Game.play_move(game, 2, {:outbid, {"a", "b"}})
    assert %Game{current_player_id: 2, current_bid: {2, 2}} = game
    assert Enum.member?(instructions, notify_player_instruction(2, :invalid_bid))

    assert {instructions, game} = Game.play_move(game, 2, {:outbid, {4, 4}})
    assert %Game{current_player_id: 1, current_bid: {4, 4}, players_hands: hands} = game

    assert Enum.member?(
             instructions,
             notify_player_instruction(
               1,
               {:move, hands[1]}
             )
           )

    assert {instructions, game} = Game.play_move(game, 1, {:outbid, {6, 2}})
    assert %Game{current_player_id: 1, current_bid: {4, 4}} = game
    assert Enum.member?(instructions, notify_player_instruction(1, :invalid_bid))

    assert {instructions, game} = Game.play_move(game, 1, {:outbid, {6, 4}})
    assert %Game{current_player_id: 2, current_bid: {6, 4}, players_hands: hands} = game

    assert Enum.member?(
             instructions,
             notify_player_instruction(
               2,
               {:move, hands[2]}
             )
           )

    assert {instructions, game} = Game.play_move(game, 2, {:outbid, {3, 1}})
    assert %Game{current_player_id: 1, current_bid: {3, 1}, players_hands: hands} = game

    assert Enum.member?(
             instructions,
             notify_player_instruction(
               1,
               {:move, hands[1]}
             )
           )

    assert {instructions, game} = Game.play_move(game, 1, {:outbid, {2, 1}})
    assert %Game{current_player_id: 1, current_bid: {3, 1}} = game
    assert Enum.member?(instructions, notify_player_instruction(1, :invalid_bid))
  end

  test "cannot outbid with face 1 die on start of game" do
    {_, game} = Game.start([1, 2], 5)
    assert %Game{current_player_id: 1, current_bid: {0, 0}} = game
    assert {instructions, game} = Game.play_move(game, 1, {:outbid, {3, 1}})
    assert %Game{current_player_id: 1, current_bid: {0, 0}} = game
    assert Enum.member?(instructions, notify_player_instruction(1, :invalid_bid))
  end

  test "cannot outbid with same bid" do
    {_, game} = Game.start([1, 2], 5)
    assert %Game{current_player_id: 1, current_bid: {0, 0}} = game
    assert {instructions, game} = Game.play_move(game, 1, {:outbid, {3, 2}})
    assert %Game{current_player_id: 2, current_bid: {3, 2}, players_hands: hands} = game

    assert Enum.member?(
             instructions,
             notify_player_instruction(
               2,
               {:move, hands[2]}
             )
           )

    assert {instructions, game} = Game.play_move(game, 2, {:outbid, {3, 2}})
    assert %Game{current_player_id: 2, current_bid: {3, 2}} = game
    assert Enum.member?(instructions, notify_player_instruction(2, :invalid_bid))
  end

  test "cannot outbid with face 1 die when new count lower then half the actual count" do
    {_, game} = Game.start([1, 2], 5)
    assert %Game{current_player_id: 1, current_bid: {0, 0}} = game

    assert {instructions, game} = Game.play_move(game, 1, {:outbid, {5, 5}})
    assert %Game{current_player_id: 2, current_bid: {5, 5}, players_hands: hands} = game

    assert Enum.member?(
             instructions,
             notify_player_instruction(
               2,
               {:move, hands[2]}
             )
           )

    assert {instructions, game} = Game.play_move(game, 2, {:outbid, {2, 1}})
    assert %Game{current_player_id: 2, current_bid: {5, 5}} = game
    assert Enum.member?(instructions, notify_player_instruction(2, :invalid_bid))
  end

  test "outbid with face 1 die" do
    {_, game} = Game.start([1, 2], 5)
    assert %Game{current_player_id: 1, current_bid: {0, 0}} = game

    assert {instructions, game} = Game.play_move(game, 1, {:outbid, {3, 2}})
    assert %Game{current_player_id: 2, current_bid: {3, 2}, players_hands: hands} = game

    assert Enum.member?(
             instructions,
             notify_player_instruction(
               2,
               {:move, hands[2]}
             )
           )

    assert {instructions, game} = Game.play_move(game, 2, {:outbid, {2, 1}})
    assert %Game{current_player_id: 1, current_bid: {2, 1}, players_hands: hands} = game

    assert Enum.member?(
             instructions,
             notify_player_instruction(
               1,
               {:move, hands[1]}
             )
           )

    assert {instructions, game} = Game.play_move(game, 1, {:outbid, {5, 1}})
    assert %Game{current_player_id: 2, current_bid: {5, 1}, players_hands: hands} = game

    assert Enum.member?(
             instructions,
             notify_player_instruction(
               2,
               {:move, hands[2]}
             )
           )
  end

  test "outbid" do
    {_, game} = Game.start([1, 2], 5)
    assert %Game{current_player_id: 1, current_bid: {0, 0}} = game

    assert {instructions, game} = Game.play_move(game, 1, {:outbid, {5, 5}})
    assert %Game{current_player_id: 2, current_bid: {5, 5}, players_hands: hands} = game

    assert Enum.member?(
             instructions,
             notify_player_instruction(
               2,
               {:move, hands[2]}
             )
           )

    assert {instructions, game} = Game.play_move(game, 2, {:outbid, {3, 1}})
    assert %Game{current_player_id: 1, current_bid: {3, 1}, players_hands: hands} = game

    assert Enum.member?(
             instructions,
             notify_player_instruction(
               1,
               {:move, hands[1]}
             )
           )

    assert {instructions, game} = Game.play_move(game, 1, {:outbid, {7, 5}})
    assert %Game{current_player_id: 2, current_bid: {7, 5}, players_hands: hands} = game

    assert Enum.member?(
             instructions,
             notify_player_instruction(
               2,
               {:move, hands[2]}
             )
           )

    assert {instructions, game} = Game.play_move(game, 2, {:outbid, {4, 1}})
    assert %Game{current_player_id: 1, current_bid: {4, 1}, players_hands: hands} = game

    assert Enum.member?(
             instructions,
             notify_player_instruction(
               1,
               {:move, hands[1]}
             )
           )

    assert {instructions, game} = Game.play_move(game, 1, {:outbid, {5, 1}})
    assert %Game{current_player_id: 2, current_bid: {5, 1}, players_hands: hands} = game

    assert Enum.member?(
             instructions,
             notify_player_instruction(
               2,
               {:move, hands[2]}
             )
           )
  end

  test "cannot calza at start of game" do
    {_, game} = Game.start([1, 2], 5)
    assert %Game{current_player_id: 1, current_bid: {0, 0}} = game

    assert {instructions, game} = Game.play_move(game, 1, :calza)
    assert %Game{current_player_id: 1, current_bid: {0, 0}} = game
    assert Enum.member?(instructions, notify_player_instruction(1, :illegal_move))
  end

  test "calza gives a dice back to the player if he's right" do
    {_, game} = Game.start([1, 2], 5)
    assert %Game{current_player_id: 1, current_bid: {0, 0}} = game

    game = %Game{
      game
      | players_hands: %{
          game.players_hands
          | 1 => %Hand{game.players_hands[1] | dice: [5, 5, 1, 5, 5]}
        }
    }

    game = %Game{
      game
      | players_hands: %{
          game.players_hands
          | 2 => %Hand{game.players_hands[2] | dice: [5, 1, 5, 5]}
        }
    }

    assert {instructions, game} = Game.play_move(game, 1, {:outbid, {9, 5}})
    assert %Game{current_player_id: 2, current_bid: {9, 5}, players_hands: hands} = game

    assert Enum.member?(
             instructions,
             notify_player_instruction(
               2,
               {:move, hands[2]}
             )
           )

    assert {instructions, game} = Game.play_move(game, 2, :calza)
    assert %Game{current_player_id: 2, current_bid: {0, 0}, players_hands: hands} = game

    assert Enum.member?(
             instructions,
             notify_player_instruction(
               2,
               {:move, hands[2]}
             )
           )

    assert Enum.member?(
             instructions,
             notify_player_instruction(2, {:last_move, 2, {:calza, true}})
           )

    assert length(hands[2].dice) == 5
    assert hands[2].remaining_dice == 5

    assert Enum.any?(
             instructions,
             &match?(notify_player_instruction(1, {:reveal_players_hands, _, {9, 5}}), &1)
           )
  end

  test "calza takes a dice if the player is wrong" do
    {_, game} = Game.start([1, 2], 5)
    assert %Game{current_player_id: 1, current_bid: {0, 0}} = game

    game = %Game{
      game
      | players_hands: %{
          game.players_hands
          | 1 => %Hand{game.players_hands[1] | dice: [5, 5, 5, 5, 5]}
        }
    }

    game = %Game{
      game
      | players_hands: %{
          game.players_hands
          | 2 => %Hand{game.players_hands[2] | dice: [5, 5, 5, 5, 5]}
        }
    }

    assert {instructions, game} = Game.play_move(game, 1, {:outbid, {9, 5}})
    assert %Game{current_player_id: 2, current_bid: {9, 5}, players_hands: hands} = game

    assert Enum.member?(
             instructions,
             notify_player_instruction(
               2,
               {:move, hands[2]}
             )
           )

    assert {instructions, game} = Game.play_move(game, 2, :calza)
    assert %Game{current_player_id: 2, current_bid: {0, 0}, players_hands: hands} = game

    assert Enum.member?(
             instructions,
             notify_player_instruction(
               2,
               {:move, hands[2]}
             )
           )

    assert Enum.member?(
             instructions,
             notify_player_instruction(2, {:last_move, 2, {:calza, false}})
           )

    assert length(game.players_hands[2].dice) == 4
    assert game.players_hands[2].remaining_dice == 4

    assert Enum.any?(
             instructions,
             &match?(notify_player_instruction(1, {:reveal_players_hands, _, {10, 5}}), &1)
           )
  end

  test "player that calls calza regardless of result is the next to play" do
    {_, game} = Game.start([1, 2], 5)
    assert %Game{current_player_id: 1, current_bid: {0, 0}} = game

    assert {instructions, game} = Game.play_move(game, 1, {:outbid, {9, 5}})
    assert %Game{current_player_id: 2, current_bid: {9, 5}, players_hands: hands} = game

    assert Enum.member?(
             instructions,
             notify_player_instruction(
               2,
               {:move, hands[2]}
             )
           )

    assert {instructions, game} = Game.play_move(game, 2, :calza)
    assert %Game{current_player_id: 2, current_bid: {0, 0}, players_hands: hands} = game

    assert Enum.member?(
             instructions,
             notify_player_instruction(
               2,
               {:move, hands[2]}
             )
           )

    assert Enum.any?(
             instructions,
             &match?(notify_player_instruction(1, {:reveal_players_hands, _, {_, 5}}), &1)
           )
  end

  test "cannot dudo at start of game" do
    {_, game} = Game.start([1, 2], 5)
    assert %Game{current_player_id: 1, current_bid: {0, 0}} = game

    assert {instructions, game} = Game.play_move(game, 1, :dudo)
    assert %Game{current_player_id: 1, current_bid: {0, 0}} = game
    assert Enum.member?(instructions, notify_player_instruction(1, :illegal_move))
  end

  test "dudo removes a dice from the caller player if he's wrong" do
    {_, game} = Game.start([1, 2], 5)
    assert %Game{current_player_id: 1, current_bid: {0, 0}} = game

    game = %Game{
      game
      | players_hands: %{
          game.players_hands
          | 1 => %Hand{game.players_hands[1] | dice: [1, 1, 5, 5, 5]}
        }
    }

    game = %Game{
      game
      | players_hands: %{
          game.players_hands
          | 2 => %Hand{game.players_hands[2] | dice: [1, 1, 5, 5, 5]}
        }
    }

    assert {instructions, game} = Game.play_move(game, 1, {:outbid, {9, 5}})
    assert %Game{current_player_id: 2, current_bid: {9, 5}, players_hands: hands} = game

    assert Enum.member?(
             instructions,
             notify_player_instruction(
               game.current_player_id,
               {:move, hands[game.current_player_id]}
             )
           )

    assert {instructions, game} = Game.play_move(game, 2, :dudo)
    assert %Game{current_player_id: 2, current_bid: {0, 0}, players_hands: hands} = game

    assert Enum.member?(
             instructions,
             notify_player_instruction(
               2,
               {:move, hands[2]}
             )
           )

    assert Enum.member?(
             instructions,
             notify_player_instruction(2, {:last_move, 2, {:dudo, false}})
           )

    assert length(game.players_hands[2].dice) == 4
    assert game.players_hands[2].remaining_dice == 4

    assert Enum.any?(
             instructions,
             &match?(notify_player_instruction(1, {:reveal_players_hands, _, {10, 5}}), &1)
           )
  end

  test "dudo removes a dice from the previous player if current player is right" do
    {_, game} = Game.start([1, 2], 5)
    assert %Game{current_player_id: 1, current_bid: {0, 0}} = game

    game = %Game{
      game
      | players_hands: %{
          game.players_hands
          | 1 => %Hand{game.players_hands[1] | dice: [1, 1, 5, 5, 5]}
        }
    }

    game = %Game{
      game
      | players_hands: %{
          game.players_hands
          | 2 => %Hand{game.players_hands[2] | dice: [1, 1, 5, 5, 5]}
        }
    }

    assert {instructions, game} = Game.play_move(game, 1, {:outbid, {11, 5}})
    assert %Game{current_player_id: 2, current_bid: {11, 5}, players_hands: hands} = game

    assert Enum.member?(
             instructions,
             notify_player_instruction(
               game.current_player_id,
               {:move, hands[2]}
             )
           )

    assert {instructions, game} = Game.play_move(game, 2, :dudo)
    assert %Game{current_player_id: 1, current_bid: {0, 0}, players_hands: hands} = game

    assert Enum.member?(
             instructions,
             notify_player_instruction(
               1,
               {:move, hands[1]}
             )
           )

    assert Enum.member?(
             instructions,
             notify_player_instruction(1, {:last_move, 2, {:dudo, true}})
           )

    assert length(game.players_hands[1].dice) == 4
    assert game.players_hands[1].remaining_dice == 4

    assert Enum.any?(
             instructions,
             &match?(notify_player_instruction(1, {:reveal_players_hands, _, {10, 5}}), &1)
           )

    assert Enum.any?(
             instructions,
             &match?(notify_player_instruction(2, {:reveal_players_hands, _, {10, 5}}), &1)
           )
  end

  test "when only one players remain, winner is announced" do
    {_, game} = Game.start(['a', 'b'], 1)
    assert %Game{current_player_id: 'a', current_bid: {0, 0}} = game

    game = %Game{
      game
      | players_hands: %{game.players_hands | 'a' => %Hand{game.players_hands['a'] | dice: [5]}}
    }

    game = %Game{
      game
      | players_hands: %{game.players_hands | 'b' => %Hand{game.players_hands['b'] | dice: [5]}}
    }

    assert {instructions, game} = Game.play_move(game, 'a', {:outbid, {2, 5}})
    assert %Game{current_player_id: 'b', current_bid: {2, 5}, players_hands: hands} = game

    assert Enum.member?(
             instructions,
             notify_player_instruction(
               'b',
               {:move, hands['b']}
             )
           )

    assert {instructions, game} = Game.play_move(game, 'b', :dudo)
    assert %Game{current_player_id: nil, current_bid: nil, players_hands: %{}} = game
    assert Enum.member?(instructions, notify_player_instruction('a', {:winner, 'a'}))
    assert Enum.member?(instructions, notify_player_instruction('b', {:loser, 'b'}))
  end

  test "when player has no more die, he is eliminated" do
    {_, game} = Game.start(['a', 'b', 'c'], 1)
    assert %Game{current_player_id: 'a', current_bid: {0, 0}} = game

    game = %Game{
      game
      | players_hands: %{game.players_hands | 'a' => %Hand{game.players_hands['a'] | dice: [5]}}
    }

    game = %Game{
      game
      | players_hands: %{game.players_hands | 'b' => %Hand{game.players_hands['b'] | dice: [5]}}
    }

    game = %Game{
      game
      | players_hands: %{game.players_hands | 'c' => %Hand{game.players_hands['c'] | dice: [5]}}
    }

    assert {instructions, game} = Game.play_move(game, 'a', {:outbid, {2, 5}})
    assert %Game{current_player_id: 'b', current_bid: {2, 5}, players_hands: hands} = game

    assert Enum.member?(
             instructions,
             notify_player_instruction(
               'b',
               {:move, hands['b']}
             )
           )

    assert {instructions, game} = Game.play_move(game, 'b', :dudo)

    assert %Game{
             current_player_id: 'c',
             current_bid: {0, 0},
             players_hands: %{'a' => _, 'c' => _}
           } = game

    assert Enum.member?(instructions, notify_player_instruction('b', {:loser, 'b'}))
  end
end
