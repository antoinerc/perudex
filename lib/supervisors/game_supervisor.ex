defmodule Perudo.Supervisors.GameSupervisor do
  @moduledoc """
  Supervisor for game servers
  """
  use DynamicSupervisor

  alias Perudo.GameServer
  alias Perudo.Supervisors.NotifierSupervisor

  def start_link(opts) do
    DynamicSupervisor.start_link(__MODULE__, opts, name: service_name(opts))
  end

  @impl true
  def init(_opts) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def start_child(id, players) do
    DynamicSupervisor.start_child(service_name(id), {GameServer, {id, players}}) |> IO.inspect()
    DynamicSupervisor.start_child(service_name(id), {NotifierSupervisor, [id, players]})
  end

  defp service_name(game_id) do
    Perudo.service_name({__MODULE__, game_id})
  end
end
