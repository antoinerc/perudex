defmodule Perudo.NotifierServer do
  use GenServer, restart: :transient

  @callback start_game(GameServer.callback_arg(), Game.player_id(), [Game.player_id()]) :: any
  @callback new_hand(GameServer.callback_arg(), Game.player_id(), Hand.t()) :: any
  @callback move(GameServer.callback_arg(), Game.player_id()) :: any
  @callback reveal_players_hands(GameServer.callback_arg(), Game.player_id(), [
              {Game.player_id(), Perudo.Hand.t()}
            ]) :: any
  @callback unauthorized_move(GameServer.callback_arg(), Game.player_id()) :: any
  @callback new_bid(GameServer.callback_arg(), Game.player_id(), Game.bid()) :: any
  @callback invalid_bid(GameServer.callback_arg(), Game.player_id()) :: any
  @callback illegal_move(GameServer.callback_arg(), Game.player_id()) :: any
  @callback successful_calza(GameServer.callback_arg(), Game.player_id()) :: any
  @callback unsuccessful_calza(GameServer.callback_arg(), Game.player_id()) :: any
  @callback successful_dudo(GameServer.callback_arg(), Game.player_id()) :: any
  @callback unsuccessful_dudo(GameServer.callback_arg(), Game.player_id()) :: any
  @callback winner(GameServer.callback_arg(), Game.player_id(), Game.player_id()) :: any
  @callback loser(GameServer.callback_arg(), Game.player_id(), Game.player_id()) :: any

  def start_link({game_id, player}) do
    GenServer.start_link(__MODULE__, {game_id, player}, name: service_name(game_id, player.id))
  end

  @impl true
  def init({game_id, player}) do
    {:ok, %{game_id: game_id, player: player}}
  end

  def publish(game_id, player_id, instruction) do
    GenServer.cast(service_name(game_id, player_id), {:notify, instruction})
  end

  @impl true
  def handle_cast({:notify, instruction}, state) do
    {fun, args} = decode_instruction(instruction)

    all_args = [state.player.callback_arg, state.player.id | args]

    apply(state.player.callback_mod, fun, all_args)
    {:noreply, state}
  end

  defp decode_instruction({:game_started, players}), do: {:start_game, [players]}
  defp decode_instruction({:new_hand, hand}), do: {:new_hand, [hand]}
  defp decode_instruction(:move), do: {:move, []}
  defp decode_instruction({:reveal_players_hands, hands}), do: {:reveal_players_hands, [hands]}
  defp decode_instruction(:unauthorized_move), do: {:unauthorized_move, []}
  defp decode_instruction({:new_bid, bid}), do: {:new_bid, [bid]}
  defp decode_instruction(:invalid_bid), do: {:invalid_bid, []}
  defp decode_instruction(:illegal_move), do: {:illegal_move, []}
  defp decode_instruction(:successful_calza), do: {:successful_calza, []}
  defp decode_instruction(:unsuccessful_calza), do: {:unsuccessful_calza, []}
  defp decode_instruction(:successful_dudo), do: {:successful_dudo, []}
  defp decode_instruction(:unsuccessful_dudo), do: {:unsuccessful_dudo, []}
  defp decode_instruction({:winner, winner_id}), do: {:winner, [winner_id]}
  defp decode_instruction({:loser, loser_id}), do: {:loser, [loser_id]}

  def service_name(game_id, player_id) do
    Perudo.service_name({__MODULE__, game_id, player_id})
  end
end
