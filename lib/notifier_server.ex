defmodule Perudo.NotifierServer do
  use GenServer, restart: :transient

  @callback start_game(GameServer.callback_arg(), any, GameServer.id()) :: any

  def start_link([game_id, player]) do
    GenServer.start_link(__MODULE__, {game_id, player}, name: service_name(game_id, player.id))
  end

  def init({game_id, player}) do
    {:ok, %{game_id: game_id, player: player}}
  end

  def publish(game_id, visibility, player_id, instruction) do
    GenServer.cast(service_name(game_id, player_id), {:notify, visibility, instruction})
  end

  def handle_cast({:notify, visibility, instruction}, state) do
    {fun, args} = decode_instruction(instruction)
    all_args = [state.player.callback_arg, visibility, state.player.id | args]
    apply(state.player.callback_mod, fun, all_args)
    {:noreply, state}
  end

  defp decode_instruction(:game_started) do
    {:game_started, []}
  end

  def service_name(game_id, player_id) do
    Perudo.service_name({__MODULE__, game_id, player_id})
  end
end
