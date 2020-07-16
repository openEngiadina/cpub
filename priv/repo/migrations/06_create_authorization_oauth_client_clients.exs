defmodule CPub.Repo.Migrations.CreateAuthenticationOAuthClientClients do
  use Ecto.Migration

  def change do
    create table(:authentication_oauth_client_clients, primary_key: false) do
      add(:id, :binary_id, primary_key: true)

      add(:provider, :string)
      add(:site, :string)

      add(:client_id, :string)
      add(:client_secret, :string)

      timestamps()
    end

    create(unique_index(:authentication_oauth_client_clients, [:provider, :site]))
  end
end
