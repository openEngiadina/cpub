defmodule CPub.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users, primary_key: false) do
      add(:id, :string, primary_key: true)
      add(:username, :string)
      add(:password, :string)
      add(:profile, :map)

      timestamps()
    end

    create(unique_index(:users, [:username]))
  end
end
