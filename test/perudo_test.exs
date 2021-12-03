defmodule PerudoTest do
  use ExUnit.Case
  doctest Perudo

  test "greets the world" do
    assert Perudo.hello() == :world
  end
end
