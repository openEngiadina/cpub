defmodule CPub.Web.OAuthServer.Authorization do
  @moduledoc """
  An OAuth 2.0 Authorization.

  An `CPub.Web.OAuthServer.Authorization` includes a code that can be used to obtain a `CPub.Web.OAuthServer.Token`. The token can be used to access resources. The Authorization can only be used once and is valid for only 10 minutes after creation.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias CPub.User
  alias CPub.Repo
  alias CPub.Web.OAuthServer.Client

  defp random_code() do
    :crypto.strong_rand_bytes(32)
    |> Base.encode32(padding: false)
  end

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "oauth_server_authorizations" do
    field :code, :string
    field :scope, :string
    field :used, :boolean, default: false

    belongs_to :user, User, type: :binary_id
    belongs_to :client, Client, type: :binary_id

    timestamps()
  end

  def changeset(%__MODULE__{} = authorization, attrs) do
    authorization
    |> cast(attrs, [:scope, :user_id, :client_id, :used])
    |> put_change(:code, random_code())
    |> validate_required([:code, :scope, :user_id, :client_id])
    # TODO: validate that scope is in client.scopes
    |> assoc_constraint(:user)
    |> assoc_constraint(:client)
    |> unique_constraint(:id, name: "oauth_server_authorizations_pkey")
  end

  def create(%{user: user, client: client, scope: scope}) do
    %__MODULE__{}
    |> changeset(%{user_id: user.id, client_id: client.id, scope: scope})
    |> Repo.insert()
  end
end
