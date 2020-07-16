defmodule CPub.Web.Authentication.Registration do
  @moduledoc """
  A `Registration` binds a local `CPub.User` to an external identity provider.
  """

  use Ecto.Schema

  import Ecto.Changeset

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

    timestamps()
  end

  def changeset(%__MODULE__{} = registration, attrs) do
    registration
    |> cast(attrs, [:user_id, :provider, :site, :external_id, :access_token, :refresh_token])
    |> validate_required([:user_id, :provider, :site, :external_id, :access_token])
    |> foreign_key_constraint(:user_id)
    |> unique_constraint(:id, name: :authentication_registration_pkey)
    |> unique_constraint(:id, name: :authentication_registration_provider_site_external_id_index)
  end

  def create(attrs) do
    %__MODULE__{}
    |> changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Retrieve a registration from information in a Ueberauth.Auth
  """
  def get_from_auth(%Ueberauth.Auth{} = auth) do
    provider = to_string(auth.provider)
    site = auth.extra.site
    external_id = auth.uuid

    with {:ok, registration} <-
           Repo.get_one_by(__MODULE__, %{provider: provider, site: site, external_id: external_id}) do
      {:ok, registration |> Repo.preload(:user)}
    end
  end
end
