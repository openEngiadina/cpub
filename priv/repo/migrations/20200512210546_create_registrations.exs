defmodule CPub.Repo.Migrations.CreateRegistrations do
  use Ecto.Migration

  def change do
    create table(:registrations) do
      add :user_id, references(:users, on_delete: :delete_all, type: :string)

      add(:username, :string)
      add(:provider, :string)
      add :info, :map

      timestamps()
    end

    create_if_not_exists unique_index(:registrations, [:username, :provider])
  end
end
