defmodule CPub.User do
  use Ecto.Schema
  import Ecto.Changeset

  alias CPub.User

  @primary_key {:id, CPub.ID, autogenerate: true}
  @foreign_key_type CPub.ID
  schema "users" do

    field :username, :string
    field :password, Comeonin.Ecto.Password

    field :profile, RDF.Description.EctoType

    # has_many :authorizations, Authorization

    timestamps()
  end

  def changeset(%User{} = user, attrs \\ %{}) do
    user
    |> cast(attrs, [:username, :password, :profile])
    |> validate_required([:username, :password, :profile])
    |> unique_constraint(:username, name: "users_username_index")
    |> unique_constraint(:id, name: "users_pkey")
  end

  def create_user(opts \\ []) do
    username = Keyword.get(opts, :username)
    password = Keyword.get(opts, :password)

    # set the ID to "/users/<username>"
    id = "users/" <> username
    |> CPub.ID.merge_with_base_url()

    profile = Keyword.get(opts, :profile, RDF.Description.new(id))

    %User{id: id}
    |> changeset(%{username: username, password: password, profile: profile})
    |> CPub.Repo.insert

  end

  def verify_user(username, password) do
    CPub.Repo.get_by(User, username: username)
    |> Pbkdf2.check_pass(password, hash_key: :password)
  end

  def get_user(username) do
    CPub.Repo.get_by(User, username: username)
  end

end