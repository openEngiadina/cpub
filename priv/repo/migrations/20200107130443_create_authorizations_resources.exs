defmodule CPub.Repo.Migrations.CreateAuthorizationsResources do
  use Ecto.Migration

  def change do
    create table (:authorizations_resources) do
      add :authorization_id, references(:authorizations, on_delete: :delete_all, type: :string)
      add :resource_id, references(:ldp_rs, on_delete: :delete_all, type: :string)
    end

    create unique_index(:authorizations_resources, [:authorization_id, :resource_id])

  end
end
