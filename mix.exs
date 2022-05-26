defmodule Perudex.MixProject do
  use Mix.Project

  def project do
    [
      app: :perudex,
      name: "Perudex",
      description: description(),
      version: "0.6.0",
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      source_url: "https://github.com/antoinerc/perudex"
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Perudex, []}
    ]
  end

  defp deps do
    [
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.27", only: :dev, runtime: false},
      {:dialyxir, "~> 1.0", only: [:dev], runtime: false}
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/antoinerc/perudex"}
    ]
  end

  defp description,
    do:
      "Perudex is a library implementing the game Perudo, also known as Dudo or Liar's Dice (which you may have heard of in the Pirates of the Caribbean movie)."
end
