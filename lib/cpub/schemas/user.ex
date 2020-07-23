defmodule CPub.User do
  @moduledoc """
  Schema for CPub user.
  """

  @behaviour Access

  use Ecto.Schema

  import Ecto.Changeset
  import Ecto.Query, only: [from: 2]

  alias CPub.{Activity, Crypto, ID, Object, Repo}
  alias CPub.NS.ActivityStreams, as: AS
  alias CPub.NS.LDP
  alias CPub.Solid.WebID

  alias CPub.Web.Authorization

  alias CPub.Web.Authentication.{Registration, Session}

  alias RDF.FragmentGraph

  @type t :: %__MODULE__{
          username: String.t() | nil,
          password: String.t() | nil,
          profile_object_id: RDF.IRI.t() | nil
        }

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "users" do
    field :username, :string
    field :password, Comeonin.Ecto.Password

    belongs_to :profile_object, Object, type: RDF.IRI.EctoType

    # OAuth 2.0 authorizations for user
    has_many :authorizations, Authorization

    # Authenticated sessions
    has_many :sessions, Session

    # If user is created from an external identity
    has_one :registration, Registration

    timestamps()
  end

  @spec changeset(t, map) :: Ecto.Changeset.t()
  def changeset(%__MODULE__{} = user, attrs) do
    user
    |> cast(attrs, [:username, :password])
    |> validate_required([:username])
    |> validate_profile()
    |> unique_constraint(:username, name: "users_username_index")
    |> unique_constraint(:id, name: "users_pkey")
    |> assoc_constraint(:profile_object)
  end

  defp validate_profile(%Ecto.Changeset{} = changeset) do
    if is_nil(get_field(changeset, :profile_object)) do
      changeset
      |> put_change(
        :profile_object,
        default_profile(%{username: get_field(changeset, :username)})
        |> CPub.Object.new()
      )
    else
      changeset
    end
  end

  @spec create(map) :: {:ok, t} | {:error, Ecto.Changeset.t()}
  def create(%{} = attrs) do
    %__MODULE__{}
    |> changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Returns an externally usable URL.

  TODO: Goal is to not rely on any base_url. How can an actor be addessed?
  """
  @spec actor_url(t) :: RDF.IRI.t()
  def actor_url(%__MODULE__{username: username}) do
    ID.merge_with_base_url("users/#{username}/")
  end

  @spec default_profile(map, boolean) :: FragmentGraph.t()
  defp default_profile(%{username: username}, from_provider? \\ false) do
    username = if from_provider?, do: "#{username}-#{Crypto.random_string(8)}", else: username

    # TODO: get rid of base url in database
    inbox_id = ID.merge_with_base_url("users/#{username}/inbox")
    outbox_id = ID.merge_with_base_url("users/#{username}/outbox")

    default_profile =
      FragmentGraph.new(RDF.UUID.generate())
      |> FragmentGraph.add(RDF.type(), AS.Person)
      |> FragmentGraph.add(LDP.inbox(), inbox_id)
      |> FragmentGraph.add(AS.outbox(), outbox_id)
      |> FragmentGraph.add(AS.preferredUsername(), username)
      |> WebID.Profile.create()

    default_profile
  end

  @doc """
  Get a single user by username and check the password
  """
  @spec get_by_password(String.t(), String.t()) :: {:ok, t} | {:error, String.t()}
  def get_by_password(username, password) do
    __MODULE__
    |> Repo.get_by(username: username)
    |> Pbkdf2.check_pass(password, hash_key: :password)
  end

  @spec get_inbox_id(t) :: RDF.IRI.t()
  def get_inbox_id(%__MODULE__{} = user) do
    ID.merge_with_base_url("users/#{user.username}/inbox")
  end

  @spec get_outbox_id(t) :: RDF.IRI.t()
  def get_outbox_id(%__MODULE__{} = user) do
    ID.merge_with_base_url("users/#{user.username}/outbox")
  end

  @doc """
  Returns a list of activities that are in the users inbox.
  """
  @spec get_inbox(t) :: RDF.Graph.t()
  def get_inbox(%__MODULE__{} = user) do
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
  def get_outbox(%__MODULE__{} = user) do
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
  def fetch(%__MODULE__{profile_object: profile}, key) do
    Access.fetch(profile, key)
  end

  @doc """
  See `RDF.Description.get_and_update`
  """
  @impl Access
  @spec get_and_update(t, atom, fun) :: {any, t}
  def get_and_update(%__MODULE__{} = user, key, fun) do
    with {get_value, new_profile} <- Access.get_and_update(user.profile_object, key, fun) do
      {get_value, %{user | profile_object: new_profile}}
    end
  end

  @doc """
  See `RDF.Description.pop`.
  """
  @impl Access
  @spec pop(t, atom) :: {any | nil, t}
  def pop(%__MODULE__{} = user, key) do
    case Access.pop(user.profile_object, key) do
      {nil, _} -> {nil, user}
      {value, new_profile} -> {value, %{user | profile_object: new_profile}}
    end
  end
end
