defmodule CPub.Repo.Migrations.CreateObjects do
  use Ecto.Migration

  def change do
    create table(:objects, primary_key: false) do
      add :id, :string, primary_key: true

      # if the activity is deleted (which should never happen), then delete the object
      add :activity_id, references(:activities, on_delete: :delete_all, type: :string)

      add :data, :map
      timestamps()
    end
  end
end
