defmodule ElixirSense.Mixfile do
  use Mix.Project

  def project do
    [app: :elixir_sense,
     version: "0.1.0",
     elixir: "~> 1.2",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     test_coverage: [tool: ExCoveralls],
     preferred_cli_env: ["coveralls": :test, "coveralls.detail": :test, "coveralls.html": :test],
     deps: deps()]
  end

  def application do
    [applications: [:logger]]
  end

  defp deps do
    [{:excoveralls, "~> 0.5", only: :test},
    {:dialyxir, "~> 0.3", only: [:dev]}]
  end
end
