defmodule CPub.Repo.Migrations.CreateAuthorization do
  use Ecto.Migration

  def change do
    # Create table for `Client`
    create table(:oauth_server_clients, primary_key: false) do
      add(:id, :binary_id, primary_key: true)

      add(:client_name, :string)
      add(:website, :string)
      add(:redirect_uris, {:array, :string})
      add(:scopes, {:array, :string})

      add(:client_secret, :string)

      timestamps()
    end

    # Create table for `Authorization`
    create table(:oauth_server_authorizations, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:authorization_code, :string)
      add(:refresh_token, :string)
      add(:scope, :string)
      add(:code_used, :boolean)

      add(:user_id, references(:users, on_delete: :delete_all, type: :binary_id))
      add(:client_id, references(:oauth_server_clients, on_delete: :delete_all, type: :binary_id))

      timestamps()
    end

    create(unique_index(:oauth_server_authorizations, [:authorization_code]))
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
