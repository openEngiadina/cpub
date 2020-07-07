defmodule CPub.Repo.Migrations.CreateObjects do
  use Ecto.Migration

  def change do
    create table(:objects, primary_key: false) do
      add(:id, :string, primary_key: true)
      add(:content, :map)
      timestamps()
    end
  end
end
