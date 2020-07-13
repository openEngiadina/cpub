defmodule CPub.Repo.Migrations.CreateAuthenticationSession do
  use Ecto.Migration

  def change do
    create table(:authentication_sessions, primary_key: false) do
      add(:id, :binary_id, primary_key: true)

      add(:user_id, references(:users, on_delete: :delete_all, type: :binary_id))

      add(:last_activity, :utc_datetime)

      timestamps()
    end
  end
end
