defmodule Faro.MixProject do
  use Mix.Project

  def project do
    [
      app: :faro,
      version: "0.1.0",
      elixir: "~> 1.20",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      compilers: [:phoenix_live_view] ++ Mix.compilers(),
      listeners: [Phoenix.CodeReloader],
      consolidate_protocols: Mix.env() != :dev,
      usage_rules: usage_rules()
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Faro.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  def cli do
    [
      preferred_envs: [precommit: :test]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:ash_oban, "~> 0.10"},
      {:sourceror, "~> 1.13", only: [:dev, :test]},
      {:ash, "~> 3.37"},
      {:ash_postgres, "~> 2.15"},
      {:ash_authentication, "~> 4.15"},
      {:ash_authentication_phoenix, "~> 2.17"},
      {:oban, "~> 2.24"},
      {:stream_data, "~> 1.4"},
      {:usage_rules, "~> 1.3", only: [:dev]},
      {:phoenix, "~> 1.8.16"},
      {:phoenix_ecto, "~> 4.7"},
      {:ecto_sql, "~> 3.14"},
      {:postgrex, "~> 0.22"},
      {:phoenix_html, "~> 4.4"},
      {:phoenix_live_reload, "~> 1.7", only: :dev},
      {:phoenix_live_view, "~> 1.2"},
      {:lazy_html, "~> 0.1", only: :test},
      {:phoenix_live_dashboard, "~> 0.9"},
      {:esbuild, "~> 0.10", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.5", runtime: Mix.env() == :dev},
      {:heroicons,
       github: "tailwindlabs/heroicons",
       tag: "v2.2.0",
       sparse: "optimized",
       app: false,
       compile: false,
       depth: 1},
      {:telemetry_metrics, "~> 1.2"},
      {:telemetry_poller, "~> 1.3"},
      {:gettext, "~> 1.0"},
      {:jason, "~> 1.4"},
      {:dns_cluster, "~> 0.3"},
      {:bandit, "~> 1.14"}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "ecto.setup", "assets.setup", "assets.build"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["compile", "tailwind faro", "esbuild faro"],
      "assets.deploy": [
        "tailwind faro --minify",
        "esbuild faro --minify",
        "phx.digest"
      ],
      "docker.up": ["cmd docker compose up -d"],
      dev: ["docker.up", "phx.server"],
      precommit: ["compile --warnings-as-errors", "deps.unlock --unused", "format", "test"]
    ]
  end

  defp usage_rules do
    [
      file: "AGENTS.md",
      usage_rules: [
        :elixir,
        :otp,
        :phoenix,
        :ash,
        :ash_postgres,
        :ash_oban
      ]
    ]
  end
end
