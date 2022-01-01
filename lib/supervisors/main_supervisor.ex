defmodule Perudo.Supervisors.MainSupervistor do
  @moduledoc """
  Main supervisor to orchestrate other supervisors
  """
  use DynamicSupervisor

  alias Perudo.Supervisors.GameSupervisor

  def start_link(opts) do
    DynamicSupervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def new_game(game_id, players) do
    DynamicSupervisor.start_child(__MODULE__, {GameSupervisor, game_id})
    GameSupervisor.start_child(game_id, players)
  end
end
