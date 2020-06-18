defmodule CPub.Repo.Migrations.AddProviderToUser do
  use Ecto.Migration

  def change do
    alter table(:users, primary_key: false) do
      add(:provider, :string)
    end

    drop(unique_index(:users, [:username]))
    create(unique_index(:users, [:username, :provider]))
  end
end
