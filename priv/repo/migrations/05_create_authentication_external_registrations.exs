defmodule CPub.Repo.Migrations.CreateAuthenticationRegistrations do
  use Ecto.Migration

  def change do
    create table(:authentication_registration_requests, primary_key: false) do
      add(:id, :binary_id, primary_key: true)

      add(:provider, :string)
      add(:site, :string)
      add(:external_id, :string)

      add(:info, :map)

      add(:access_token, :string)
      add(:refresh_token, :string)
      add(:token_type, :string)

      timestamps()
    end

    create table(:authentication_registrations, primary_key: false) do
      add(:id, :binary_id, primary_key: true)

      add(:user_id, references(:users, on_delete: :delete_all, type: :binary_id))

      add(:provider, :string)
      add(:site, :string)
      add(:external_id, :string)

      add(:access_token, :string)
      add(:refresh_token, :string)
      add(:token_type, :string)

      timestamps()
    end

    create(unique_index(:authentication_registrations, [:provider, :site, :external_id]))
  end
end
