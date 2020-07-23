defmodule CPub.Web.Authorization do
  @moduledoc """
  An OAuth 2.0 Authorization.

  An `CPub.Web.Authorization.Authorization` includes a code that can be used to obtain a `CPub.Web.Authorization.Token`. The token can be used to access resources. The Authorization can only be used once and is valid for only 10 minutes after creation.

  The `CPub.Web.Authorization.Authorization` remains in the database and can be reused to refresh a token (see https://tools.ietf.org/html/rfc6749#section-6) until it is explicitly revoked (deleted). On deletion all `CPub.Web.Authorization.Token`s that were created based on the Authorization are revoked (deleted).

  Protected routes have a authorization assigned (see `CPub.Web.Authorization.AuthorizationPlug`).
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias CPub.{Repo, User}

  alias CPub.Web.Authorization.{Client, Token}

  defp random_code do
    :crypto.strong_rand_bytes(32)
    |> Base.encode32(padding: false)
  end

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "oauth_server_authorizations" do
    field :scope, :string

    # TODO: is this needed?
    field :redirect_uri, :string

    # TODO rename to :authorization_code
    field :code, :string
    # TODO rename to :code_used
    field :used, :boolean, default: false
    field :refresh_token, :string

    belongs_to :user, User, type: :binary_id
    belongs_to :client, Client, type: :binary_id

    has_many :tokens, Token

    timestamps()
  end

  def changeset(%__MODULE__{} = authorization, attrs) do
    authorization
    |> cast(attrs, [:scope, :redirect_uri, :user_id, :client_id, :used])
    |> validate_required([:scope, :redirect_uri, :user_id, :client_id])
    # TODO: validate that scope is in client.scopes
    |> assoc_constraint(:user)
    |> assoc_constraint(:client)
    |> unique_constraint(:id, name: "oauth_server_authorizations_pkey")
    |> unique_constraint(:code, name: "oauth_server_authorizations_code_index")
  end

  def create(%{user: user, client: client, scope: scope, redirect_uri: redirect_uri}) do
    %__MODULE__{}
    |> changeset(%{
      user_id: user.id,
      client_id: client.id,
      scope: scope,
      redirect_uri: redirect_uri
    })
    |> put_change(:code, random_code())
    |> put_change(:refresh_token, random_code())
    |> Repo.insert()
  end

  @doc """
  Returns a changeset that sets the authorization as used.
  """
  def use_changeset(%__MODULE__{} = authorization) do
    authorization
    |> changeset(%{used: true})
  end

  @doc """
  Returns the number of seconds the Authorization code is valid for after initial creation.
  """
  # one hour
  def valid_for, do: 3600

  @doc """
  Returns true if the `Authorization` has expired (has been created more than 10 minutes ago).
  """
  def expired?(%__MODULE__{} = authentication) do
    valid_for() <= NaiveDateTime.diff(NaiveDateTime.utc_now(), authentication.inserted_at)
  end
end
