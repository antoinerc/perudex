defmodule Perudex.NotifierServer do
  @moduledoc """
  This module is a GenServer to handle communication going to the players by defining an interface a module need to implements.
  """
  use GenServer, restart: :transient

  alias Perudex.{Game, GameServer, Hand}

  @callback start_game(GameServer.callback_arg(), Game.player_id(), [Game.player_id()]) :: any
  @callback new_hand(GameServer.callback_arg(), Game.player_id(), Hand.t()) :: any
  @callback last_move(
              GameServer.callback_arg(),
              Game.player_id(),
              Game.player_id(),
              Game.move_result()
            ) :: any
  @callback move(GameServer.callback_arg(), Game.player_id(), Hand.t()) :: any
  @callback next_player(GameServer.callback_arg(), Game.player_id(), Game.player_id()) :: any
  @callback reveal_players_hands(
              GameServer.callback_arg(),
              Game.player_id(),
              [
                {Game.player_id(), Perudex.Hand.t()}
              ],
              {integer, integer}
            ) :: any
  @callback unauthorized_move(GameServer.callback_arg(), Game.player_id()) :: any
  @callback invalid_bid(GameServer.callback_arg(), Game.player_id()) :: any
  @callback illegal_move(GameServer.callback_arg(), Game.player_id()) :: any
  @callback winner(GameServer.callback_arg(), Game.player_id(), Game.player_id()) :: any
  @callback loser(GameServer.callback_arg(), Game.player_id(), Game.player_id()) :: any
  @callback phase_change(GameServer.callback_arg(), Game.player_id(), Game.game_phase()) :: any

  def start_link({game_id, player}),
    do:
      GenServer.start_link(__MODULE__, {game_id, player}, name: service_name(game_id, player.id))

  @impl true
  def init({game_id, player}), do: {:ok, %{game_id: game_id, player: player}}

  @spec publish(any, any, Game.player_instruction()) :: :ok
  def publish(game_id, player_id, instruction),
    do: GenServer.cast(service_name(game_id, player_id), {:notify, instruction})

  @impl true
  def handle_cast({:notify, instruction}, state) do
    {fun, args} = decode_instruction(instruction)

    all_args = [state.player.callback_arg, state.player.id | args]

    apply(state.player.callback_mod, fun, all_args)
    {:noreply, state}
  end

  defp decode_instruction({:game_started, players}), do: {:start_game, [players]}
  defp decode_instruction({:new_hand, hand}), do: {:new_hand, [hand]}
  defp decode_instruction({:move, hand}), do: {:move, [hand]}
  defp decode_instruction({:next_player, player_id}), do: {:next_player, [player_id]}

  defp decode_instruction({:reveal_players_hands, hands, result}),
    do: {:reveal_players_hands, [hands, result]}

  defp decode_instruction(:unauthorized_move), do: {:unauthorized_move, []}

  defp decode_instruction({:last_move, player_id, move_result}),
    do: {:last_move, [player_id, move_result]}

  defp decode_instruction(:invalid_bid), do: {:invalid_bid, []}
  defp decode_instruction(:illegal_move), do: {:illegal_move, []}
  defp decode_instruction({:winner, winner_id}), do: {:winner, [winner_id]}
  defp decode_instruction({:loser, loser_id}), do: {:loser, [loser_id]}
  defp decode_instruction({:phase_change, phase}), do: {:phase_change, [phase]}

  defp service_name(game_id, player_id),
    do: Perudex.service_name({__MODULE__, game_id, player_id})
end
