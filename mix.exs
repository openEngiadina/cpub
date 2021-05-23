# SPDX-FileCopyrightText: 2020-2021 pukkamustard <pukkamustard@posteo.net>
# SPDX-FileCopyrightText: 2020-2021 rustra <rustra@disroot.org>
#
# SPDX-License-Identifier: CC0-1.0

defmodule CPub.MixProject do
  use Mix.Project

  def project do
    [
      app: :cpub,
      version: "0.3.0-dev",
      elixir: "~> 1.9",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: [:phoenix, :gettext] ++ Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      dialyzer: dialyzer(),
      deps: deps(),
      test_coverage: [tool: ExCoveralls],

      # Use the :test environment when running checks
      preferred_cli_env: [check: :test],

      # Docs
      name: "CPub",
      homepage_url: "https://openengiadina.net/",
      source_url: "https://gitlab.com/openengiadina/cpub",
      docs: [
        extras: ["README.md", "CHANGELOG.md"] ++ Path.wildcard("docs/*.md"),
        main: "readme",
        # TODO: to some nicer grouping
        groups_for_modules: [
          Schema: [CPub.User, CPub.User.Registration],
          Database: [CPub.DB, CPub.ERIS],
          Namespaces: [CPub.NS],
          RDF: [RDF.JSON],
          Authentication: [CPub.Web.Authentication],
          Authorization: [CPub.Web.Authorization]
        ],
        nest_modules_by_prefix: [CPub.Web.Authentication, CPub.Web.Authorization]
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
      # Phoenix, Web and Database
      {:phoenix, "~> 1.5.9"},
      {:phoenix_pubsub, "~> 2.0"},
      {:phoenix_html, "~> 2.14"},
      {:plug_cowboy, "~> 2.0"},
      {:corsica, "~> 1.1"},
      {:gettext, "~> 0.11"},
      {:tesla, "~> 1.4.0", override: true},
      {:castore, "~> 0.1"},
      {:cowlib, "~> 2.9", override: true},
      {:gun, "~> 2.0.0-rc.1", override: true},
      {:concurrent_limiter, "~> 0.1.1"},

      # Mnesia/QLC wrapper
      {:memento, "~> 0.3.1"},
      {:qlc, "~> 1.0"},

      # Authorizaiton & Authentication
      {:ueberauth, "~> 0.6.3"},
      {:oauth2, "~> 2.0"},
      {:joken, "~> 2.2"},
      {:jason, "~> 1.2"},

      # RDF
      {:rdf, "~> 0.9.3"},
      {:json_ld, "~> 0.3.3"},
      {:elixir_uuid, "~> 1.2"},

      # ERIS & content-addressing
      {:eris, git: "https://gitlab.com/openengiadina/elixir-eris", branch: "main"},
      {:magnet, "~> 0.1.0"},

      # User passwords
      # TODO: replace argon2_elixir with argon2i from :monocypher
      {:argon2_elixir, "~> 2.3"},

      # Auxiliary
      {:con_cache, "~> 1.0"},

      # dev & test
      {:stream_data, "~> 0.5"},
      {:credo, "~> 1.5", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.23", only: :dev, runtime: false},
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
      check: ["deps.get", "format", "credo --strict", "test"]
    ]
  end
end
