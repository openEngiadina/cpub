defmodule CPub.User do
  @moduledoc """
  Schema for CPub user.
  """

  @behaviour Access

  use Ecto.Schema

  import Ecto.Changeset
  import Ecto.Query, only: [from: 2]

  alias CPub.{Activity, ID, Repo}
  alias CPub.NS.ActivityStreams, as: AS
  alias CPub.NS.LDP

  @type t :: %__MODULE__{
          id: RDF.IRI.t() | nil,
          username: String.t() | nil,
          password: String.t() | nil,
          profile: RDF.Description.t() | nil
        }

  @primary_key {:id, ID, autogenerate: true}
  @foreign_key_type ID
  schema "users" do
    field :username, :string
    field :password, Comeonin.Ecto.Password

    field :profile, RDF.Description.EctoType

    # has_many :authorizations, Authorization

    timestamps()
  end

  @spec changeset(t, map) :: Ecto.Changeset.t()
  def changeset(%__MODULE__{} = user, attrs \\ %{}) do
    user
    |> cast(attrs, [:username, :password, :profile])
    |> validate_required([:username, :password, :profile])
    |> unique_constraint(:username, name: "users_username_index")
    |> unique_constraint(:id, name: "users_pkey")
  end

  @spec create(keyword) :: {:ok, t} | {:error, Ecto.Changeset.t()}
  def create(opts \\ []) do
    username = Keyword.get(opts, :username)
    password = Keyword.get(opts, :password)

    # set the ID to "/users/<username>"
    id = ID.merge_with_base_url("users/#{username}")
    inbox_id = ID.merge_with_base_url("users/#{username}/inbox")
    outbox_id = ID.merge_with_base_url("users/#{username}/outbox")

    default_profile =
      RDF.Description.new(id)
      |> RDF.Description.add(RDF.type(), RDF.iri(AS.Person))
      |> RDF.Description.add(LDP.inbox(), inbox_id)
      |> RDF.Description.add(AS.outbox(), outbox_id)

    profile = Keyword.get(opts, :profile, default_profile)

    %__MODULE__{id: id}
    |> changeset(%{username: username, password: password, profile: profile})
    |> Repo.insert()
  end

  @spec verify_user(String.t(), String.t()) :: {:ok, t} | {:error, String.t()}
  def verify_user(username, password) do
    __MODULE__
    |> Repo.get_by(username: username)
    |> Pbkdf2.check_pass(password, hash_key: :password)
  end

  @spec get_user(String.t()) :: t | nil
  def get_user(username) do
    Repo.get_by(__MODULE__, username: username)
  end

  @spec get_inbox_id(t) :: RDF.IRI.t()
  def get_inbox_id(user) do
    ID.merge_with_base_url("users/#{user.username}/inbox")
  end

  @spec get_outbox_id(t) :: RDF.IRI.t()
  def get_outbox_id(user) do
    ID.merge_with_base_url("users/#{user.username}/outbox")
  end

  @doc """
  Returns a list of activities that are in the users inbox.
  """
  @spec get_inbox(t) :: RDF.Graph.t()
  def get_inbox(user) do
    inbox_query = from a in Activity, where: ^user.id in a.recipients

    inbox_query
    |> Repo.all()
    |> Repo.preload(:object)
    |> Activity.as_container(get_inbox_id(user))
  end

  @doc """
  Returns activities that have been performed by user.
  """
  @spec get_outbox(t) :: RDF.Graph.t()
  def get_outbox(user) do
    outbox_query = from a in Activity, where: ^user.id == a.actor

    outbox_query
    |> Repo.all()
    |> Repo.preload(:object)
    |> Activity.as_container(get_outbox_id(user))
  end

  @doc """
  See `RDF.Description.fetch`.
  """
  @impl Access
  @spec fetch(t, atom) :: {:ok, any} | :error
  def fetch(%__MODULE__{profile: profile}, key) do
    Access.fetch(profile, key)
  end

  @doc """
  See `RDF.Description.get_and_update`
  """
  @impl Access
  @spec get_and_update(t, atom, fun) :: {any, t}
  def get_and_update(%__MODULE__{} = user, key, fun) do
    with {get_value, new_profile} <- Access.get_and_update(user.profile, key, fun) do
      {get_value, %{user | profile: new_profile}}
    end
  end

  @doc """
  See `RDF.Description.pop`.
  """
  @impl Access
  @spec pop(t, atom) :: {any | nil, t}
  def pop(%__MODULE__{} = user, key) do
    case Access.pop(user.profile, key) do
      {nil, _} ->
        {nil, user}

      {value, new_profile} ->
        {value, %{user | profile: new_profile}}
    end
  end
end
