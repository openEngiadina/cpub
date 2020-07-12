defmodule CPub.Repo.Migrations.CreateOAuthServer do
  use Ecto.Migration

  def change do
    create table(:oauth_server_clients, primary_key: false) do
      add(:id, :binary_id, primary_key: true)

      add(:client_name, :string)
      add(:redirect_uris, {:array, :string})

      add(:client_id, :string)
      add(:client_secret, :string)

      timestamps()
    end

    create(unique_index(:oauth_server_clients, [:client_id, :client_secret]))
  end
end
