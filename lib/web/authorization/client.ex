defmodule CPub.Web.Authorization.Client do
  @moduledoc """
  An OAuth 2.0 client that authenticates with CPub (see https://tools.ietf.org/html/rfc6749#section-2).
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias CPub.Repo

  alias CPub.Web.Authorization.Scope

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "oauth_server_clients" do
    field :client_name, :string
    field :redirect_uris, {:array, :string}
    field :scope, {:array, Scope}

    field :client_secret, :string

    timestamps()
  end

  defp random_id_token do
    :crypto.strong_rand_bytes(32)
    |> Base.encode32(padding: false)
  end

  def changeset(%__MODULE__{} = client, attrs) do
    client
    |> cast(attrs, [:client_name, :redirect_uris, :scope])
    |> put_change(:client_secret, random_id_token())
    |> validate_required([:client_name, :redirect_uris, :scope])
    |> unique_constraint(:id, name: "oauth_server_clients_pkey")
  end

  @doc """
  Create a new OAuth 2.0 client.
  """
  def create(attrs) do
    %__MODULE__{}
    |> changeset(attrs)
    |> Repo.insert()
  end

  # Check if redirect uri is valid for client
  defp redirect_uri_valid?(uri, %__MODULE__{} = client) do
    if uri in client.redirect_uris do
      {:ok, URI.parse(uri)}
    else
      :error
    end
  end

  @doc """
  Returns a single redirect uri.

  If `params` contains a `"redirect_uri"` key the value will be checked to match the `redirect_uris` of the client.

  If `params` does not contain a `redirect_uri` the first uri from client.redirect_uris will be used.
  """
  def get_redirect_uri(%__MODULE__{} = client, %{} = params) do
    Map.get(params, "redirect_uri", client.redirect_uris |> List.first())
    |> redirect_uri_valid?(client)
  end

  defp scope_valid?(scope, %__MODULE__{} = client) do
    if scope in client.scope do
      {:ok, scope}
    else
      :error
    end
  end
end
