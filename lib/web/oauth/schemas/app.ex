defmodule CPub.Web.OAuth.App do
  @moduledoc """
  Schema for OAuth application.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias CPub.{Crypto, Repo}
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
    field(:trusted, :boolean, default: true)

    has_many(:authorizations, Authorization, on_delete: :delete_all)
    has_many(:tokens, Token, on_delete: :delete_all)

    timestamps()
  end

  @spec create_changeset(t, map) :: Ecto.Changeset.t()
  def create_changeset(%__MODULE__{} = app, attrs \\ %{}) do
    changeset =
      app
      |> cast(attrs, [:client_name, :redirect_uris, :scopes, :website, :trusted])
      |> validate_required([:client_name, :redirect_uris, :scopes])
      |> unique_constraint(:client_name, name: "oauth_apps_client_name_provider_index")

    if changeset.valid? do
      changeset
      |> put_change(:provider, "local")
      |> put_change(:client_id, Crypto.random_string(32))
      |> put_change(:client_secret, Crypto.random_string(32))
    else
      changeset
    end
  end

  @spec create_from_provider_changeset(t, map) :: Ecto.Changeset.t()
  defp create_from_provider_changeset(%__MODULE__{} = app, attrs) do
    app
    |> cast(attrs, [
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
    |> unique_constraint(:client_name, name: "oauth_apps_client_name_provider_index")
  end

  @spec create(Ecto.Changeset.t() | map) :: {:ok, t} | {:error, Ecto.Changeset.t()}
  def create(%Ecto.Changeset{} = changeset), do: Repo.insert(changeset)

  def create(attrs) do
    %__MODULE__{}
    |> create_changeset(attrs)
    |> Repo.insert()
  end

  @spec create_from_provider(map) :: {:ok, t} | {:error, Ecto.Changeset.t()}
  def create_from_provider(attrs) do
    %__MODULE__{}
    |> create_from_provider_changeset(attrs)
    |> Repo.insert()
  end

  @spec get_by(map) :: t | nil
  def get_by(attrs) do
    Repo.get_by(__MODULE__, attrs)
  end

  @spec get_provider(String.t()) :: String.t()
  def get_provider(provider_url) do
    uri = URI.parse(provider_url)
    port = if uri.port in [80, 443], do: "", else: ":#{uri.port}"

    "#{uri.host}#{port}"
  end

  @spec get_or_create(map, [String.t()]) :: {:ok, t} | {:error, Ecto.Changeset.t()}
  def get_or_create(attrs, scopes) do
    case get_by(attrs) do
      %__MODULE__{} = app -> update_scopes(app, scopes)
      nil -> create(Map.put(attrs, :scopes, scopes))
    end
  end

  @spec get_or_create_local_app :: {:ok, t} | {:error, Ecto.Changeset.t()}
  def get_or_create_local_app do
    get_or_create(
      %{client_name: "local", provider: "local", redirect_uris: ".", trusted: true},
      ["read"]
    )
  end

  @spec update_scopes(t, [String.t()]) :: {:ok, t} | {:error, Ecto.Changeset.t()}
  defp update_scopes(%__MODULE__{} = app, []), do: {:ok, app}
  defp update_scopes(%__MODULE__{scopes: scopes} = app, scopes), do: {:ok, app}

  defp update_scopes(%__MODULE__{} = app, scopes) do
    app
    |> change(%{scopes: scopes})
    |> Repo.update()
  end
end
