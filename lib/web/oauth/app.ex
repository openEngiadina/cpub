defmodule CPub.Web.OAuth.App do
  @moduledoc """
  Schema for OAuth application.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias CPub.Repo
  alias CPub.Web.OAuth.{Authorization, Token}

  @type t :: %__MODULE__{
          client_name: String.t() | nil,
          provider: String.t() | nil,
          redirect_uris: String.t() | nil,
          scopes: [String.t()] | nil,
          website: String.t() | nil,
          client_id: String.t() | nil,
          client_secret: String.t() | nil,
          trusted: boolean | nil
        }

  schema "oauth_apps" do
    field(:client_name, :string)
    field(:provider, :string)
    field(:redirect_uris, :string)
    field(:scopes, {:array, :string}, default: [])
    field(:website, :string)
    field(:client_id, :string)
    field(:client_secret, :string)
    field(:trusted, :boolean, default: false)

    has_many(:authorizations, Authorization, on_delete: :delete_all)
    has_many(:tokens, Token, on_delete: :delete_all)

    timestamps()
  end

  @spec create_from_provider_changeset(t, map) :: Ecto.Changeset.t()
  def create_from_provider_changeset(app, params \\ %{}) do
    app
    |> cast(params, [
      :client_name,
      :provider,
      :redirect_uris,
      :scopes,
      :website,
      :client_id,
      :client_secret,
      :trusted
    ])
    |> validate_required([
      :client_name,
      :provider,
      :redirect_uris,
      :scopes,
      :client_id,
      :client_secret,
      :trusted
    ])
    |> unique_constraint(:username, name: "oauth_apps_provider_client_name_index")
  end

  @spec create_from_provider(map) :: {:ok, t} | {:error, Ecto.Changeset.t()}
  def create_from_provider(params) do
    %__MODULE__{}
    |> create_from_provider_changeset(params)
    |> Repo.insert()
  end

  @spec get_provider(String.t()) :: String.t()
  def get_provider(provider_url), do: URI.parse(provider_url).host
end
