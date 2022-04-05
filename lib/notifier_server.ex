defmodule Perudo.NotifierServer do
  use GenServer, restart: :transient

  @callback start_game(GameServer.callback_arg(), any) :: any
  @callback new_hand(GameServer.callback_arg(), Game.player_id, any) :: any
  @callback move(GameServer.callback_arg(), Game.player_id, any) :: any

  def start_link({game_id, player}) do
    GenServer.start_link(__MODULE__, {game_id, player}, name: service_name(game_id, player.id))
  end

  @impl true
  def init({game_id, player}) do
    {:ok, %{game_id: game_id, player: player}}
  end

  def publish(game_id, visibility, player_id, instruction) do
    GenServer.cast(service_name(game_id, player_id), {:notify, visibility, instruction})
  end

  @impl true
  def handle_cast({:notify, visibility, instruction}, state) do
    {fun, args} = decode_instruction(instruction)

    all_args =
      case visibility do
        :public -> [state.player.callback_arg | args]
        :private -> [state.player.callback_arg, state.player.id | args]
      end

    apply(state.player.callback_mod, fun, all_args)
    {:noreply, state}
  end

  defp decode_instruction({:game_started, players}) do
    {:start_game, [players]}
  end

  defp decode_instruction({:new_hand, hand}) do
    {:new_hand, [hand]}
  end

  defp decode_instruction({:move, player}) do
    {:move, [player]}
  end

  def service_name(game_id, player_id) do
    Perudo.service_name({__MODULE__, game_id, player_id})
  end
end
