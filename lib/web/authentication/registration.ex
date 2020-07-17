defmodule CPub.Web.Authentication.Registration do
  @moduledoc """
  A `Registration` binds a local `CPub.User` to an external identity provider.
  """

  use Ecto.Schema

  import Ecto.Changeset
  alias Ecto.Multi

  alias CPub.{Repo, User}
  alias Ueberauth.Auth

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "authentication_registrations" do
    belongs_to :user, User, type: :binary_id

    # external identity provider (pleroma or oidc)
    field :provider, :string
    # the site of the identity provider
    field :site, :string
    # an external identifier
    field :external_id, :string

    # OAuth 2.0 access and refresh token
    field :access_token, :string
    field :refresh_token, :string
    field :token_type, :string

    timestamps()
  end

  def changeset(%__MODULE__{} = registration, attrs) do
    registration
    |> cast(attrs, [
      :user_id,
      :provider,
      :site,
      :external_id,
      :access_token,
      :refresh_token,
      :token_type
    ])
    |> validate_required([:user_id, :provider, :site, :external_id, :access_token, :token_type])
    |> foreign_key_constraint(:user_id)
    |> unique_constraint(:id, name: :authentication_registration_pkey)
    # There can only be a single registration for an external identity (identified by provider, site and external_id)
    |> unique_constraint(:id, name: :authentication_registration_provider_site_external_id_index)
  end

  @doc """
  Register a new user with an external idenity.
  """
  def create(username, request) do
    Multi.new()
    |> Multi.insert(:user, User.changeset(%User{}, %{username: username}))
    |> Multi.insert(:registration, fn %{user: user} ->
      %__MODULE__{}
      |> changeset(%{
        user_id: user.id,
        provider: request.provider,
        site: request.site,
        external_id: request.external_id,
        access_token: request.access_token,
        refresh_token: request.refresh_token,
        token_type: request.token_type
      })
    end)
    |> Multi.delete(:delete_request, request)
    |> Repo.transaction()
  end

  @doc """
  Get a registration from an `Uberauth.Auth`
  """
  def get_from_auth(%Ueberauth.Auth{} = auth, site) do
    provider = to_string(auth.provider)
    external_id = auth.uid

    with {:ok, registration} <-
           Repo.get_one_by(__MODULE__, %{provider: provider, site: site, external_id: external_id}) do
      {:ok, registration |> Repo.preload(:user)}
    end
  end
end
