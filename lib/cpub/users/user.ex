defmodule CPub.Users.User do
  use Ecto.Schema
  import Ecto.Changeset

  alias CPub.ActivityPub.Actor

  alias CPub.Users.User
  alias CPub.WebACL.Authorization

  @primary_key {:id, CPub.ID, autogenerate: true}
  @foreign_key_type CPub.ID
  schema "users" do

    field :username, :string
    field :password, Comeonin.Ecto.Password

    belongs_to :actor, Actor, type: CPub.ID

    has_many :authorizations, Authorization

    timestamps()
  end

  def changeset(%User{} = user, attrs \\ %{}) do
    user
    |> cast(attrs, [:id, :username, :password, :actor_id])
    |> validate_required([:username, :password, :actor_id])
    |> assoc_constraint(:actor)
    |> unique_constraint(:username, name: "users_username_index")
  end
end
