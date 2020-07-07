defmodule CPub.Repo.Migrations.CreateActivities do
  use Ecto.Migration

  def change do
    create table(:activities, primary_key: false) do
      add(:id, :string, primary_key: true)

      add(:type, :string)
      add(:actor, :string)
      add(:recipients, {:array, :string})

      add(:activity_object_id, references(:objects, on_delete: :delete_all, type: :string))
      add(:object_id, references(:objects, on_delete: :delete_all, type: :string))

      timestamps()
    end
  end
end
