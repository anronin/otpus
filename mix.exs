defmodule Otpus.MixProject do
  use Mix.Project

  def project do
    [
      app: :otpus,
      version: "0.1.0",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Otpus.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:plug, "~> 1.16"},
      {:bandit, "~> 1.6"}
    ]
  end

  defp aliases do
    [test: "test --no-start"]
  end
end
