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

  alias RDF.FragmentGraph

  @type t :: %__MODULE__{
          username: String.t() | nil,
          password: String.t() | nil,
          provider: String.t() | nil,
          profile_object_id: RDF.IRI.t() | nil
        }

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "users" do
    field :username, :string
    field :password, Comeonin.Ecto.Password

    belongs_to :profile_object, Object, type: RDF.IRI.EctoType

    # has_many :authorizations, Authorization

    # TODO: can the provider field be replaced for registrations?
    # has_many :registrations, Registration
    field :provider, :string

    timestamps()
  end

  @spec create_changeset(t) :: Ecto.Changeset.t()
  defp create_changeset(%__MODULE__{} = user) do
    user
    |> change()
    |> validate_required([:username, :password, :profile_object])
    |> put_change(:provider, "local")
    |> unique_constraint(:username, name: "users_username_provider_index")
    |> unique_constraint(:id, name: "users_pkey")
  end

  @spec create_from_provider_changeset(t, map) :: Ecto.Changeset.t()
  defp create_from_provider_changeset(%__MODULE__{} = user, attrs) do
    user
    |> cast(attrs, [:username, :provider, :profile])
    |> validate_required([:username, :provider, :profile])
    |> unique_constraint(:username, name: "users_username_provider_index")
    |> unique_constraint(:id, name: "users_pkey")
  end

  @spec create(map) :: {:ok, t} | {:error, Ecto.Changeset.t()}
  def create(%{username: username, password: password} = attrs) do
    profile_object = default_profile(attrs) |> Object.new()

    %__MODULE__{username: username, password: password, profile_object: profile_object}
    |> create_changeset()
    |> Repo.insert()
  end

  # TODO fix (profile -> profile_object)
  @spec create_from_provider(map) :: {:ok, t} | {:error, Ecto.Changeset.t()}
  def create_from_provider(%{username: username, provider: provider} = attrs) do
    {id, default_profile} = default_profile(attrs, true)
    profile = Map.get(attrs, :profile, default_profile)

    %__MODULE__{id: id}
    |> create_from_provider_changeset(%{username: username, provider: provider, profile: profile})
    |> Repo.insert()
  end

  @spec default_profile(map, boolean) :: FragmentGraph.t()
  defp default_profile(%{username: username}, from_provider? \\ false) do
    username = if from_provider?, do: "#{username}-#{Crypto.random_string(8)}", else: username

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

  @spec get_by(map) :: t | nil
  def get_by(attrs) do
    Repo.get_by(__MODULE__, attrs)
  end

  @spec get_by_password(String.t(), String.t()) :: {:ok, t} | {:error, String.t()}
  def get_by_password(username, password) do
    __MODULE__
    |> Repo.get_by(username: username)
    |> Pbkdf2.check_pass(password, hash_key: :password)
  end

  @spec get_cached_by_id(String.t() | RDF.IRI.t()) :: t | nil
  def get_cached_by_id(id) do
    key = "id:#{id}"

    with {:ok, nil} <- Cachex.get(:user_cache, key),
         user when not is_nil(user) <- get_by(%{id: id}),
         {:ok, true} <- Cachex.put(:user_cache, key, user) do
      user
    else
      {:ok, user} -> user
      nil -> nil
    end
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
    with {get_value, new_profile} <- Access.get_and_update(user.profile, key, fun) do
      {get_value, %{user | profile_object: new_profile}}
    end
  end

  @doc """
  See `RDF.Description.pop`.
  """
  @impl Access
  @spec pop(t, atom) :: {any | nil, t}
  def pop(%__MODULE__{} = user, key) do
    case Access.pop(user.profile, key) do
      {nil, _} -> {nil, user}
      {value, new_profile} -> {value, %{user | profile_object: new_profile}}
    end
  end
end
