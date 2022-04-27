defmodule Perudex.GameRegistry do
  @moduledoc """
  This module define the Registry to keep the game state in memory.
  """
  def child_spec(),
    do:
      Registry.child_spec(keys: :unique, name: __MODULE__, partitions: System.schedulers_online())
end
