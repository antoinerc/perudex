defmodule Perudo.Supervisors.NotifierSupervisor do
  @moduledoc """
  Supervisor for notifications servers
  """
  use DynamicSupervisor

  def start_link(opts) do
    DynamicSupervisor.start_link(__MODULE__, opts, name: service_name(opts))
  end

  @impl true
  def init(_opts) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def start_child(game) do
    # Enum.each(game.players, fn player ->
    #   DynamicSupervisor.start_child(
    #     service_name(game.id),
    #     {Servers.PlayerNotifier, [game.id, Updater.player_spec(game.id, player.user_id)]}
    #   )
    # end)
  end

  defp service_name(game_id) do
    Perudo.service_name({__MODULE__, game_id})
  end
end
