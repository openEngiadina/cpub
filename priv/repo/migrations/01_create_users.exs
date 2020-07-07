defmodule CPub.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:username, :string)
      add(:password, :string)

      add(:profile_object_id, references(:objects, on_delete: :delete_all, type: :string))

      add(:provider, :string)

      timestamps()
    end

    create(unique_index(:users, [:username, :provider]))
  end
end
