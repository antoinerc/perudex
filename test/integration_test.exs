defmodule Perudex.IntegrationTest do
  use ExUnit.Case, async: true
  @behaviour Perudex.NotifierServer

  test "game with two players" do
    {:ok, _} =
      Perudex.Supervisors.MainSupervisor.create_game(:game_1, [
        %{id: :player_1, callback_mod: __MODULE__, callback_arg: self()},
        %{id: :player_2, callback_mod: __MODULE__, callback_arg: self()}
      ])

    # Start of game
    assert_receive {:player_1, {:start_game, [:player_1, :player_2]}}
    assert_receive {:player_2, {:start_game, [:player_1, :player_2]}}
    assert_receive {:player_1, {:move, %{dice: _, remaining_dice: 5}}}
    assert_receive {:player_1, {:new_hand, %{dice: _, remaining_dice: 5}}}
    assert_receive {:player_2, {:new_hand, %{dice: _, remaining_dice: 5}}}

    # Moves
    Perudex.GameServer.move(:game_1, :player_2, :dudo)
    assert_receive {:player_2, :unauthorized_move}

    Perudex.GameServer.move(:game_1, :player_1, :dudo)
    assert_receive {:player_1, :illegal_move}

    Perudex.GameServer.move(:game_1, :player_1, {:outbid, {0, 1}})
    assert_receive {:player_1, :invalid_bid}

    Perudex.GameServer.move(:game_1, :player_1, {:outbid, {2, 2}})
    assert_receive {:player_1, {:last_move, :player_1, {:outbid, {2, 2}}}}
    assert_receive {:player_2, {:last_move, :player_1, {:outbid, {2, 2}}}}
    assert_receive {:player_2, {:move, %{dice: _, remaining_dice: 5}}}

    Perudex.GameServer.move(:game_1, :player_2, {:outbid, {4, 2}})
    assert_receive {:player_1, {:last_move, :player_2, {:outbid, {4, 2}}}}
    assert_receive {:player_2, {:last_move, :player_2, {:outbid, {4, 2}}}}
    assert_receive {:player_1, {:move, %{dice: _, remaining_dice: 5}}}

    Perudex.GameServer.move(:game_1, :player_1, {:outbid, {120, 1}})
    assert_receive {:player_1, {:last_move, :player_1, {:outbid, {120, 1}}}}
    assert_receive {:player_2, {:last_move, :player_1, {:outbid, {120, 1}}}}
    assert_receive {:player_2, {:move, %{dice: _, remaining_dice: 5}}}

    Perudex.GameServer.move(:game_1, :player_2, :dudo)

    assert_receive {:player_1,
                    {:reveal_players_hands,
                     [
                       %{hand: %Perudex.Hand{dice: _, remaining_dice: 4}, player_id: :player_1},
                       %{hand: %Perudex.Hand{dice: _, remaining_dice: 5}, player_id: :player_2}
                     ], {_, 1}}}

    assert_receive {:player_2,
                    {:reveal_players_hands,
                     [
                       %{hand: %Perudex.Hand{dice: _, remaining_dice: 4}, player_id: :player_1},
                       %{hand: %Perudex.Hand{dice: _, remaining_dice: 5}, player_id: :player_2}
                     ], {_, 1}}}

    assert_receive {:player_1, {:new_hand, %{dice: _, remaining_dice: 4}}}
    assert_receive {:player_2, {:new_hand, %{dice: _, remaining_dice: 5}}}
    assert_receive {:player_1, {:last_move, :player_2, {:dudo, true}}}
    assert_receive {:player_2, {:last_move, :player_2, {:dudo, true}}}
    assert_receive {:player_1, {:move, %{dice: _, remaining_dice: 4}}}

    Perudex.GameServer.move(:game_1, :player_1, {:outbid, {10, 3}})
    assert_receive {:player_1, {:last_move, :player_1, {:outbid, {10, 3}}}}
    assert_receive {:player_2, {:last_move, :player_1, {:outbid, {10, 3}}}}
    assert_receive {:player_2, {:move, %{dice: _, remaining_dice: 5}}}

    Perudex.GameServer.move(:game_1, :player_2, :dudo)

    assert_receive {:player_1,
                    {:reveal_players_hands,
                     [
                       %{hand: %Perudex.Hand{dice: _, remaining_dice: 3}, player_id: :player_1},
                       %{hand: %Perudex.Hand{dice: _, remaining_dice: 5}, player_id: :player_2}
                     ], {_, 3}}}

    assert_receive {:player_2,
                    {:reveal_players_hands,
                     [
                       %{hand: %Perudex.Hand{dice: _, remaining_dice: 3}, player_id: :player_1},
                       %{hand: %Perudex.Hand{dice: _, remaining_dice: 5}, player_id: :player_2}
                     ], {_, 3}}}

    assert_receive {:player_1, {:new_hand, %{dice: _, remaining_dice: 3}}}
    assert_receive {:player_2, {:new_hand, %{dice: _, remaining_dice: 5}}}
    assert_receive {:player_1, {:last_move, :player_2, {:dudo, true}}}
    assert_receive {:player_2, {:last_move, :player_2, {:dudo, true}}}
    assert_receive {:player_1, {:move, %{dice: _, remaining_dice: 3}}}

    Perudex.GameServer.move(:game_1, :player_1, {:outbid, {10, 3}})
    assert_receive {:player_1, {:last_move, :player_1, {:outbid, {10, 3}}}}
    assert_receive {:player_2, {:last_move, :player_1, {:outbid, {10, 3}}}}
    assert_receive {:player_2, {:move, %{dice: _, remaining_dice: 5}}}

    Perudex.GameServer.move(:game_1, :player_2, :dudo)

    assert_receive {:player_1,
                    {:reveal_players_hands,
                     [
                       %{hand: %Perudex.Hand{dice: _, remaining_dice: 2}, player_id: :player_1},
                       %{hand: %Perudex.Hand{dice: _, remaining_dice: 5}, player_id: :player_2}
                     ], {_, 3}}}

    assert_receive {:player_2,
                    {:reveal_players_hands,
                     [
                       %{hand: %Perudex.Hand{dice: _, remaining_dice: 2}, player_id: :player_1},
                       %{hand: %Perudex.Hand{dice: _, remaining_dice: 5}, player_id: :player_2}
                     ], {_, 3}}}

    assert_receive {:player_1, {:new_hand, %{dice: _, remaining_dice: 2}}}
    assert_receive {:player_2, {:new_hand, %{dice: _, remaining_dice: 5}}}
    assert_receive {:player_1, {:last_move, :player_2, {:dudo, true}}}
    assert_receive {:player_2, {:last_move, :player_2, {:dudo, true}}}
    assert_receive {:player_1, {:move, %{dice: _, remaining_dice: 2}}}

    Perudex.GameServer.move(:game_1, :player_1, {:outbid, {10, 3}})
    assert_receive {:player_1, {:last_move, :player_1, {:outbid, {10, 3}}}}
    assert_receive {:player_2, {:last_move, :player_1, {:outbid, {10, 3}}}}
    assert_receive {:player_2, {:move, %{dice: _, remaining_dice: 5}}}

    Perudex.GameServer.move(:game_1, :player_2, :dudo)

    assert_receive {:player_1,
                    {:reveal_players_hands,
                     [
                       %{hand: %Perudex.Hand{dice: _, remaining_dice: 1}, player_id: :player_1},
                       %{hand: %Perudex.Hand{dice: _, remaining_dice: 5}, player_id: :player_2}
                     ], {_, 3}}}

    assert_receive {:player_2,
                    {:reveal_players_hands,
                     [
                       %{hand: %Perudex.Hand{dice: _, remaining_dice: 1}, player_id: :player_1},
                       %{hand: %Perudex.Hand{dice: _, remaining_dice: 5}, player_id: :player_2}
                     ], {_, 3}}}

    assert_receive {:player_1, {:new_hand, %{dice: _, remaining_dice: 1}}}
    assert_receive {:player_2, {:new_hand, %{dice: _, remaining_dice: 5}}}
    assert_receive {:player_1, {:last_move, :player_2, {:dudo, true}}}
    assert_receive {:player_2, {:last_move, :player_2, {:dudo, true}}}
    assert_receive {:player_1, {:move, %{dice: _, remaining_dice: 1}}}

    Perudex.GameServer.move(:game_1, :player_1, {:outbid, {10, 3}})
    assert_receive {:player_1, {:last_move, :player_1, {:outbid, {10, 3}}}}
    assert_receive {:player_2, {:last_move, :player_1, {:outbid, {10, 3}}}}
    assert_receive {:player_2, {:move, %{dice: _, remaining_dice: 5}}}

    Perudex.GameServer.move(:game_1, :player_2, :dudo)

    assert_receive {:player_1,
                    {:reveal_players_hands,
                     [
                       %{hand: %Perudex.Hand{dice: _, remaining_dice: 0}, player_id: :player_1},
                       %{hand: %Perudex.Hand{dice: _, remaining_dice: 5}, player_id: :player_2}
                     ], {_, 3}}}

    assert_receive {:player_2,
                    {:reveal_players_hands,
                     [
                       %{hand: %Perudex.Hand{dice: _, remaining_dice: 0}, player_id: :player_1},
                       %{hand: %Perudex.Hand{dice: _, remaining_dice: 5}, player_id: :player_2}
                     ], {_, 3}}}

    assert_receive {:player_1, {:loser, :player_1}}
    assert_receive {:player_2, {:loser, :player_1}}

    assert_receive {:player_1, {:winner, :player_2}}
    assert_receive {:player_2, {:winner, :player_2}}

    assert_receive {:player_1, {:last_move, :player_2, {:dudo, true}}}
    assert_receive {:player_2, {:last_move, :player_2, {:dudo, true}}}
  end

  def start_game(test_pid, player_id, players),
    do: send(test_pid, {player_id, {:start_game, players}})

  def new_hand(test_pid, player_id, hand), do: send(test_pid, {player_id, {:new_hand, hand}})

  def move(test_pid, player_id, hand), do: send(test_pid, {player_id, {:move, hand}})

  def reveal_players_hands(test_pid, player_id, hands, result),
    do: send(test_pid, {player_id, {:reveal_players_hands, hands, result}})

  def unauthorized_move(test_pid, player_id), do: send(test_pid, {player_id, :unauthorized_move})

  def last_move(test_pid, player_id, actor, move),
    do: send(test_pid, {player_id, {:last_move, actor, move}})

  def invalid_bid(test_pid, player_id), do: send(test_pid, {player_id, :invalid_bid})

  def illegal_move(test_pid, player_id), do: send(test_pid, {player_id, :illegal_move})

  def winner(test_pid, player_id, winner_id),
    do: send(test_pid, {player_id, {:winner, winner_id}})

  def loser(test_pid, player_id, loser_id), do: send(test_pid, {player_id, {:loser, loser_id}})
end
