defmodule CPub.MixProject do
  use Mix.Project

  def project do
    [
      app: :cpub,
      version: "0.3.0-dev",
      elixir: "~> 1.5",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: [:phoenix, :gettext] ++ Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      dialyzer: dialyzer(),
      deps: deps(),
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
      # Phoenix, Web and Databse
      {:phoenix, "~> 1.5"},
      {:phoenix_pubsub, "~> 2.0"},
      {:phoenix_html, "~> 2.14"},
      {:plug_cowboy, "~> 2.0"},
      {:corsica, "~> 1.1"},
      {:gettext, "~> 0.11"},

      # Mnesia wrapper
      {:memento, "~> 0.3.1"},

      # Ecto
      {:phoenix_ecto, "~> 4.0"},
      {:ecto_sql, "~> 3.0"},
      {:ecto_enum, "~> 1.4"},
      {:postgrex, ">= 0.0.0"},

      # Authorizaiton & Authentication
      {:ueberauth, "~> 0.6.3"},
      {:oauth2, "~> 2.0"},
      {:joken, "~> 2.2"},
      {:jason, "~> 1.2"},

      # RDF
      {:rdf, "~> 0.8"},
      {:json_ld, "~> 0.3"},
      {:elixir_uuid, "~> 1.2"},

      # ERIS & content-addressing
      {:eris, git: "https://gitlab.com/openengiadina/elixir-eris", branch: "main"},
      # for some reason transitive dependencies are not automatically fetched (probably because manually fetching from git)
      {:monocypher, git: "https://gitlab.com/openengiadina/erlang-monocypher", branch: "main"},

      # User passwords
      {:comeonin_ecto_password, "~> 3.0.0"},
      {:pbkdf2_elixir, "~> 1.2"},
      # TODO: replace argon2_elixir with argon2i from :monocypher
      {:argon2_elixir, "~> 2.3"},

      # dev & test
      {:stream_data, "~> 0.5"},
      {:credo, "~> 1.2", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.21", only: :dev, runtime: false},
      {:excoveralls, "~> 0.13", only: :test},
      {:dialyxir, "~> 1.0.0-rc.7", only: [:dev, :test], runtime: false}
    ]
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
