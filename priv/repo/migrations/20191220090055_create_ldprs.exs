defmodule CPub.Repo.Migrations.CreateLDPRS do
  use Ecto.Migration

  def change do
    create table(:ldp_rs, primary_key: false) do
      add :id, :string, primary_key: true
      add :data, :map
      timestamps()
    end
  end
end
