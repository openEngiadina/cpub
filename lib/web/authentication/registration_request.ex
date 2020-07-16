defmodule CPub.Web.Authentication.RegistrationRequest do
  @moduledoc """
  A request to register with an external identiy provider.

  This is a temporary entitiy that only exists while the user has authenticated with external provider but not created an associated local user yet.

  We store this temporary data in a database instead of sending it to the client (as HTTP request params) as it contains sensitive information that should not be leaked to the user (access token).

  This is exactly a `CPub.Web.Authentication.Registration` withouth the `:user` field.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias CPub.{Repo, User}
  alias Ueberauth.Auth

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "authentication_registration_requests" do
    # external identity provider (pleroma or oidc)
    field :provider, :string
    # the site of the identity provider
    field :site, :string
    # an external identifier
    field :external_id, :string

    # any information that can be used to create username/initial user profile
    field :info, :map

    # OAuth 2.0 access and refresh token
    field :access_token, :string
    field :refresh_token, :string
    field :token_type, :string

    timestamps()
  end

  def changeset(%__MODULE__{} = registration, attrs) do
    registration
    |> cast(attrs, [
      :provider,
      :site,
      :external_id,
      :access_token,
      :refresh_token,
      :token_type,
      :info
    ])
    |> validate_required([:provider, :site, :external_id, :access_token, :token_type])
    |> unique_constraint(:id, name: :authentication_registration_pkey)
  end

  @doc """
  Create a registration request from information in an `Ueberauth.Auth`
  """
  def create(%Ueberauth.Auth{} = auth) do
    %__MODULE__{}
    |> changeset(%{
      provider: to_string(auth.provider),
      site: auth.extra.raw_info.site,
      external_id: auth.uid,
      info: %{username: auth.info.nickname},
      access_token: auth.credentials.token,
      refresh_token: auth.credentials.refresh_token,
      token_type: auth.credentials.token_type
    })
    |> Repo.insert()
  end
end
