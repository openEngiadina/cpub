defmodule CPub.Release do
  @moduledoc """
  Helpers for migrating database from release builds.
  """

  @app :cpub

  def migrate do
    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  def rollback(repo, version) do
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  defp repos do
    :ok = Application.load(@app)

    Application.fetch_env!(@app, :ecto_repos)
  end
end
