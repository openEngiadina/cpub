defmodule CPub.MixProject do
  use Mix.Project

  def project do
    [
      app: :cpub,
      version: "0.1.0",
      elixir: "~> 1.5",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: [:phoenix, :gettext] ++ Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),

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
      {:ecto_sql, "~> 3.0"},
      {:postgrex, ">= 0.0.0"},
      {:gettext, "~> 0.11"},
      {:jason, "~> 1.0"},
      {:plug_cowboy, "~> 2.0"},
      {:rdf, "~> 0.7.0"},
      {:sparql, "~> 0.3.4"},
      {:stream_data, "~> 0.4.3"},
      {:json_ld, "~> 0.3.0"},
      {:comeonin_ecto_password, "~> 3.0.0"},
      {:pbkdf2_elixir, "~> 1.0.2"},
      {:cors_plug, "~> 2.0"},
      {:credo, "~> 1.2", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.21", only: :dev, runtime: false}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to create, migrate and run the seeds file at once:
  #
  #     $ mix ecto.setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate", "test"]
    ]
  end
end
