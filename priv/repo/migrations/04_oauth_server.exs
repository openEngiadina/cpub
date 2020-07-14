defmodule CPub.Repo.Migrations.CreateOAuthServer do
  use Ecto.Migration

  def change do
    # Create table for `Client`
    create table(:oauth_server_clients, primary_key: false) do
      add(:id, :binary_id, primary_key: true)

      add(:client_name, :string)
      add(:website, :string)
      add(:redirect_uris, {:array, :string})
      add(:scopes, {:array, :string})

      add(:client_id, :string)
      add(:client_secret, :string)

      timestamps()
    end

    create(unique_index(:oauth_server_clients, [:client_id, :client_secret]))

    # Create table for `Authorization`
    create table(:oauth_server_authorizations, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:code, :string)
      add(:refresh_token, :string)
      add(:scope, :string)
      add(:redirect_uri, :string)
      add(:used, :boolean)

      add(:user_id, references(:users, on_delete: :delete_all, type: :binary_id))
      add(:client_id, references(:oauth_server_clients, on_delete: :delete_all, type: :binary_id))

      timestamps()
    end

    create(unique_index(:oauth_server_authorizations, [:code]))
    create(unique_index(:oauth_server_authorizations, [:refresh_token]))

    # Create table for `Token`
    create table(:oauth_server_tokens, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:access_token, :string)

      add(
        :authorization_id,
        references(:oauth_server_authorizations, on_delete: :delete_all, type: :binary_id)
      )

      timestamps()
    end

    create(unique_index(:oauth_server_tokens, [:access_token]))
  end
end
