defmodule CPub.User do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query, only: [from: 2]

  alias CPub.NS.ActivityStreams, as: AS
  alias CPub.NS.LDP

  @behaviour Access

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

    inbox_id = "users/" <> username <> "/inbox"
    |> CPub.ID.merge_with_base_url()

    outbox_id = "users/" <> username <> "/outbox"
    |> CPub.ID.merge_with_base_url()

    profile = Keyword.get(opts, :profile,
      RDF.Description.new(id)
      |> RDF.Description.add(RDF.type, AS.Person)
      |> RDF.Description.add(LDP.inbox, inbox_id)
      |> RDF.Description.add(AS.outbox, outbox_id))

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

  @doc """
  Returns a list of activities that are in the users inbox.
  """
  def get_inbox(user) do
    inbox_query = from a in CPub.Activity,
      where: ^user.id in a.recipients
    CPub.Repo.all(inbox_query)
    |> CPub.Repo.preload(:object)
  end

  @doc """
  Returns activities that have been performed by user.
  """
  def get_outbox(user) do
    outbox_query = from a in CPub.Activity,
      where: ^user.id == a.actor
    CPub.Repo.all(outbox_query)
    |> CPub.Repo.preload(:object)
  end

  @doc """
  See `RDF.Description.fetch`.
  """
  @impl Access
  def fetch(%User{profile: profile}, key) do
    Access.fetch(profile, key)
  end

  @doc """
  See `RDF.Description.get_and_update`
  """
  @impl Access
  def get_and_update(%User{} = user, key, fun) do
    with {get_value, new_profile} <- Access.get_and_update(user.profile, key, fun) do
      {get_value, %{user | profile: new_profile}}
    end
  end

  @doc """
  See `RDF.Description.pop`.
  """
  @impl Access
  def pop(%User{} = user, key) do
    case Access.pop(user.profile, key) do
      {nil, _} ->
        {nil, user}

      {value, new_profile} ->
        {value, %{user | profile: new_profile}}
    end
  end
end
