defmodule CPub.Web.OAuthServer.Client do
  @moduledoc """
  An OAuth 2.0 client that authenticates with CPub (see https://tools.ietf.org/html/rfc6749#section-2).
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias CPub.Repo

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "oauth_server_clients" do
    field :client_name, :string
    field :redirect_uris, {:array, :string}, default: []

    field :client_id, :string
    field :client_secret, :string

    timestamps()
  end

  defp random_id_token() do
    :crypto.strong_rand_bytes(32)
    |> Base.encode32(padding: false)
  end

  def changeset(%__MODULE__{} = client, attrs) do
    client
    |> cast(attrs, [:client_name, :redirect_uris])
    |> put_change(:client_id, random_id_token())
    |> put_change(:client_secret, random_id_token())
    |> validate_required([:client_name, :redirect_uris])
    |> unique_constraint(:id, name: "oauth_server_clients_pkey")
    |> unique_constraint(:client_id, name: "oauth_server_clients_client_id_client_secret_index")
  end

  @doc """
  Create a new OAuth 2.0 client.
  """
  def create(attrs) do
    %__MODULE__{}
    |> changeset(attrs)
    |> Repo.insert()
  end
end
