defmodule CPub.Users.User do
  use Ecto.Schema
  import Ecto.Changeset

  alias CPub.ActivityPub.Actor

  alias CPub.Users.User

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "users" do

    field :username, :string
    field :password, Comeonin.Ecto.Password

    belongs_to :actor, Actor, type: CPub.ID

    timestamps()
  end

  def changeset(%User{} = user, attrs \\ %{}) do
    user
    |> cast(attrs, [:username, :password, :actor_id])
    |> validate_required([:username, :password, :actor_id])
    |> unique_constraint(:username, name: "users_username_index")
  end
end
