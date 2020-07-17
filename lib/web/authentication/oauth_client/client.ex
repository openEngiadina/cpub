defmodule CPub.Web.Authentication.OAuthClient.Client do
  @moduledoc """
  Stores client_id and client_secret for a dynamically setup OAuth 2.0 client.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias CPub.Repo

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "authentication_oauth_client_clients" do
    # external identity provider (pleroma or oidc)
    field :provider, :string

    # the site of the identity provider (in OIDC lingo: issuer)
    field :site, :string

    field :client_id, :string
    field :client_secret, :string
    timestamps()
  end

  def changeset(%__MODULE__{} = client, attrs) do
    client
    |> cast(attrs, [:provider, :site, :client_id, :client_secret])
    |> validate_required([:provider, :site, :client_id, :client_secret])
    |> unique_constraint(:id, name: :authentication_oauth_client_clients_pkey)
    |> unique_constraint(:provider_site,
      name: :authentication_oauth_client_clients_provider_site_index
    )
  end

  def create(attrs) do
    %__MODULE__{}
    |> changeset(attrs)
    |> Repo.insert()
  end
end
