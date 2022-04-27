defmodule Perudex do
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [Perudex.GameRegistry.child_spec(), Perudex.Supervisors.MainSupervistor]

    opts = [strategy: :one_for_one, name: Perudex.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def service_name(service_id), do: {:via, Registry, {Perudex.GameRegistry, service_id}}
end
