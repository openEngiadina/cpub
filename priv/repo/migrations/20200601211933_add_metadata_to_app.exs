defmodule CPub.Repo.Migrations.AddMetadataToApp do
  use Ecto.Migration

  def change do
    alter table(:oauth_apps) do
      add(:metadata, :map, default: %{})
    end
  end
end
