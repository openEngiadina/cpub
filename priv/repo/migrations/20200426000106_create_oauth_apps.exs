defmodule CPub.Repo.Migrations.CreateOauthApps do
  use Ecto.Migration

  def change do
    create table(:oauth_apps) do
      add(:client_name, :string)
      add(:provider, :string)
      add(:redirect_uris, :string)
      add(:scopes, {:array, :string}, default: [], null: false)
      add(:website, :string)
      add(:client_id, :string)
      add(:client_secret, :string)
      add(:trusted, :boolean)

      timestamps()
    end

    create unique_index(:oauth_apps, [:provider, :client_name])
  end
end
