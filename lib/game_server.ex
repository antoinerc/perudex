defmodule Perudo.GameServer do
  use GenServer, restart: :transient

  alias Perudo.{Game, NotifierServer}

  @type id :: any
  @type player :: %{id: any, callback_mod: module, callback_arg: any}
  @type callback_arg :: any

  @impl true
  def init({id, players_ids}) do
    {:ok, players_ids |> Game.start(5) |> handle_move_result(%{id: id, game: nil})}
  end

  def start_link({id, players}) do
    GenServer.start_link(__MODULE__, {id, Enum.map(players, & &1.id)}, name: service_name(id))
  end

  defp handle_move_result({instructions, game}, state),
    do: Enum.reduce(instructions, %{state | game: game}, &handle_instruction(&2, &1))

  defp handle_instruction(state, {:notify_player, visibility, player_id, instruction_payload}) do
    NotifierServer.publish(state.id, visibility, player_id, instruction_payload)
    state
  end

  defp service_name(game_id), do: Perudo.service_name({__MODULE__, game_id})
end
