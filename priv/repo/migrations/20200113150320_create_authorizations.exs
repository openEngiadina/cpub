defmodule CPub.Repo.Migrations.CreateAuthorizations do
  use Ecto.Migration

  def change do
    create table (:authorizations) do
      add :user_id, references(:users, on_delete: :delete_all, type: :string)
      add :resource_id, references(:ldp_rs, on_delete: :delete_all, type: :string)

      add :read, :boolean
      add :write, :boolean
    end

    create unique_index(:authorizations, [:user_id, :resource_id, :read, :write])

  end
end
