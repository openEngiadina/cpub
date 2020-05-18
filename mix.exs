defmodule CPub.MixProject do
  use Mix.Project

  def project do
    [
      app: :cpub,
      version: "0.2.0-dev",
      elixir: "~> 1.5",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: [:phoenix, :gettext] ++ Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      dialyzer: dialyzer(),
      deps: deps() ++ oauth_deps(),
      test_coverage: [tool: ExCoveralls],

      # Docs
      name: "CPub",
      homepage_url: "https://openengiadina.net/",
      source_url: "https://gitlab.com/openengiadina/cpub",
      docs: [
        extras: ["README.md", "CHANGELOG.md"] ++ Path.wildcard("docs/*.md"),
        main: "readme",
        # TODO: to some nicer grouping
        groups_for_modules: [
          Schema: [CPub.Object, CPub.User, CPub.Activity],
          Namespaces: [CPub.NS],
          Types: [CPub.ID],
          RDF: [RDF.JSON]
        ]
      ]
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {CPub.Application, []},
      extra_applications: [:logger, :runtime_tools]
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
      {:phoenix, "~> 1.4.3"},
      {:phoenix_pubsub, "~> 1.1"},
      {:phoenix_ecto, "~> 4.0"},
      {:phoenix_html, "~> 2.14"},
      {:plug_cowboy, "~> 2.0"},
      {:cors_plug, "~> 2.0"},
      {:ecto_sql, "~> 3.0"},
      {:postgrex, ">= 0.0.0"},
      {:comeonin_ecto_password, "~> 3.0.0"},
      {:pbkdf2_elixir, "~> 1.0.2"},
      {:oauth2, "~> 0.8.2"},
      {:ueberauth, "~> 0.5.0"},
      {:gettext, "~> 0.11"},
      {:cachex, "~> 3.2"},
      {:jason, "~> 1.0"},
      {:poison, "~> 4.0"},
      {:rdf, "~> 0.7.1"},
      {:sparql, "~> 0.3.4"},
      {:json_ld, "~> 0.3.0"},
      {:stream_data, "~> 0.4.3"},
      {:comeonin_ecto_password, "~> 3.0.0"},
      {:pbkdf2_elixir, "~> 1.0.2"},
      {:corsica, "~> 1.1"},
      {:credo, "~> 1.2", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.21", only: :dev, runtime: false},
      {:excoveralls, "~> 0.12.2", only: :test},
      {:dialyxir, "~> 1.0.0-rc.7", only: [:dev, :test], runtime: false}
    ]
  end

  # Specifies OAuth dependencies.
  def oauth_deps do
    not_public_consumer_strategies = ["oidc", "cpub", "pleroma"]

    System.get_env("AUTH_CONSUMER_STRATEGIES")
    |> to_string()
    |> String.split()
    |> Kernel.--(not_public_consumer_strategies)
    |> Enum.map(fn strategy_entry ->
      with [_strategy, dependency] <- String.split(strategy_entry, ":") do
        dependency
      else
        [strategy] -> "ueberauth_#{strategy}"
      end
    end)
    |> Enum.map(&{String.to_atom(&1), ">= 0.0.0"})
  end

  defp dialyzer do
    [
      plt_add_apps: [:mix],
      ignore_warnings: ".dialyzer_ignore",
      flags: [:unmatched_returns, :error_handling, :race_conditions]
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  defp aliases do
    [
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate", "test"],
      doctor: ["deps.get", "format", "credo --strict", "dialyzer"]
    ]
  end
end
