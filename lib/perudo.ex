defmodule Perudo do
  use Application

  @moduledoc """
  Documentation for `Perudo`.
  """

  def start(_type, _args) do
    children = [Perudo.GameRegistry.child_spec(), Perudo.Supervisors.MainSupervistor]

    opts = [strategy: :one_for_one, name: Perudo.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def service_name(service_id), do: {:via, Registry, {Perudo.GameRegistry, service_id}}
end
