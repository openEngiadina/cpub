defmodule CPub.Repo.Migrations.CreateActivities do
  use Ecto.Migration

  def change do
    create table(:activities, primary_key: false) do
      add :id, :string, primary_key: true
      add :type, :string
      add :actor, :string
      add :recipients, {:array, :string}
      add :data, :map
      timestamps()
    end
  end
end
