defmodule CPub.Repo.Migrations.CreateAuthorizations do
  use Ecto.Migration

  def change do
    create table(:authorizations, primary_key: false) do
      add :id, :string, primary_key: true

      add :user_id, references(:users, on_delete: :delete_all, type: :string)

      add :mode_read, :boolean
      add :mode_write, :boolean
      add :mode_append, :boolean
      add :mode_control, :boolean

      timestamps()
    end

  end
end
