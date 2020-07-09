defmodule CPub.Repo.Migrations.CreateOAuthAuthorizations do
  use Ecto.Migration

  def change do
    create table(:oauth_authorizations) do
      add(:app_id, references(:oauth_apps, on_delete: :delete_all, type: :integer))
      add(:user_id, references(:users, on_delete: :delete_all, type: :binary_id))

      add(:code, :string)
      add(:scopes, {:array, :string}, default: [], null: false)
      add(:valid_until, :naive_datetime_usec)
      add(:used, :boolean)

      timestamps()
    end

    create_if_not_exists(unique_index(:oauth_authorizations, [:code]))

    create_if_not_exists(index(:oauth_authorizations, [:app_id]))
  end
end
