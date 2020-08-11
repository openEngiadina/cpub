defmodule CPub.Repo.Migrations.CreateOAuthTokens do
  use Ecto.Migration

  def change do
    create table(:oauth_tokens) do
      # add(:app_id, references(:oauth_apps, on_delete: :delete_all, type: :integer))
      add(:user_id, references(:users, on_delete: :delete_all, type: :binary_id))

      add(:access_token, :string)
      add(:refresh_token, :string)
      add(:scopes, {:array, :string}, default: [], null: false)
      add(:valid_until, :naive_datetime_usec)

      timestamps()
    end

    # create_if_not_exists(index(:oauth_tokens, [:app_id]))
    create_if_not_exists(index(:oauth_tokens, [:user_id]))

    create_if_not_exists(unique_index(:oauth_tokens, [:access_token]))
    create_if_not_exists(unique_index(:oauth_tokens, [:refresh_token]))
  end
end
