defmodule CPub.Web.OAuth.Token do
  @moduledoc """
  Schema for OAuth token.
  """

  use Ecto.Schema

  import Ecto.Changeset
  import Ecto.Query

  alias CPub.{Config, Crypto, Repo, User}
  alias CPub.Web.JWT
  alias CPub.Web.OAuth.{App, Authorization}

  @type t :: %__MODULE__{
          access_token: String.t() | nil,
          refresh_token: String.t() | nil,
          scopes: [String.t()] | nil,
          id_token: String.t() | nil,
          valid_until: NaiveDateTime.t() | nil,
          user_id: RDF.IRI.t() | nil,
          app_id: integer | nil
        }

  schema "oauth_tokens" do
    field :access_token, :string
    field :refresh_token, :string
    field :scopes, {:array, :string}, default: []
    field :id_token, :string, virtual: true
    field :valid_until, :naive_datetime_usec

    belongs_to :user, User, type: CPub.ID
    belongs_to :app, App

    timestamps()
  end

  @spec create_token(App.t(), User.t(), map) :: {:ok, t} | {:error, Ecto.Changeset.t()}
  def create_token(%App{} = app, %User{} = user, attrs \\ %{}) do
    token_creation =
      %__MODULE__{user_id: user.id, app_id: app.id}
      |> cast(%{scopes: attrs[:scopes] || app.scopes}, [:scopes])
      |> validate_required([:scopes, :user_id, :app_id])
      |> put_valid_until(attrs)
      |> put_access_token()
      |> put_refresh_token(attrs)
      |> Repo.insert()

    case token_creation do
      {:ok, token} -> {:ok, put_id_token(token, user)}
      {:error, _} = error -> error
    end
  end

  @spec get_by_access_token(App.t(), String.t()) :: {:ok, t} | {:error, atom}
  def get_by_access_token(%App{id: app_id}, access_token) do
    __MODULE__
    |> by_app(app_id)
    |> by_access_token(access_token)
    |> Repo.get_one()
  end

  @spec get_by_refresh_token(App.t(), String.t()) :: {:ok, t} | {:error, atom}
  def get_by_refresh_token(%App{id: app_id}, refresh_token) do
    __MODULE__
    |> by_app(app_id)
    |> by_refresh_token(refresh_token)
    |> Repo.get_one()
  end

  @spec exchange_token(App.t(), Authorization.t()) :: {:ok, t} | {:error, Ecto.Changeset.t()}
  def exchange_token(%App{} = app, %Authorization{} = auth) do
    with {:ok, auth} <- Authorization.use_code(auth),
         true <- auth.app_id == app.id do
      user = if auth.user_id, do: User.get_cached_by_id(auth.user_id), else: %User{}

      create_token(app, user, %{scopes: auth.scopes})
    end
  end

  @spec serialize(t, map) :: map
  def serialize(%__MODULE__{} = token, opts \\ %{}) do
    %{
      token_type: "Bearer",
      access_token: token.access_token,
      refresh_token: token.refresh_token,
      expires_in: expires_in(),
      scope: Enum.join(token.scopes, " ")
    }
    |> merge_id_token(token)
    |> Map.merge(opts)
  end

  @spec serialize_for_client_credentials(t) :: map
  def serialize_for_client_credentials(%__MODULE__{} = token) do
    %{
      token_type: "Bearer",
      access_token: token.access_token,
      refresh_token: token.refresh_token,
      created_at: format_creation_date(token.inserted_at),
      expires_in: expires_in(),
      scope: Enum.join(token.scopes, " ")
    }
    |> merge_id_token(token)
  end

  @spec build_id_token(User.t()) :: String.t()
  def build_id_token(%User{id: user_id}) do
    claims = %{"sub" => user_id.value}
    with {:ok, id_token, _} <- JWT.generate_and_sign(claims, :rs256), do: id_token
  end

  @spec merge_id_token(map, t) :: map
  defp merge_id_token(token, %__MODULE__{id_token: nil}), do: token

  defp merge_id_token(token, %__MODULE__{id_token: id_token}) do
    Map.merge(token, %{id_token: id_token})
  end

  @spec format_creation_date(NaiveDateTime.t()) :: integer
  def format_creation_date(inserted_at) do
    inserted_at
    |> DateTime.from_naive!("Etc/UTC")
    |> DateTime.to_unix()
  end

  @spec put_valid_until(Ecto.Changeset.t(), map) :: Ecto.Changeset.t()
  defp put_valid_until(changeset, attrs) do
    expires_in =
      Map.get(attrs, :valid_until, NaiveDateTime.add(NaiveDateTime.utc_now(), expires_in()))

    changeset
    |> change(%{valid_until: expires_in})
    |> validate_required([:valid_until])
  end

  @spec put_access_token(Ecto.Changeset.t()) :: Ecto.Changeset.t()
  defp put_access_token(changeset) do
    changeset
    |> change(%{access_token: Crypto.random_string(32)})
    |> validate_required([:access_token])
    |> unique_constraint(:access_token)
  end

  @spec put_refresh_token(Ecto.Changeset.t(), map) :: Ecto.Changeset.t()
  defp put_refresh_token(changeset, attrs) do
    refresh_token = Map.get(attrs, :refresh_token, Crypto.random_string(32))

    changeset
    |> change(%{refresh_token: refresh_token})
    |> validate_required([:refresh_token])
    |> unique_constraint(:refresh_token)
  end

  @spec put_id_token(t, User.t()) :: t
  defp put_id_token(%__MODULE__{scopes: scopes} = token, %User{} = user) do
    case "openid" in scopes do
      true -> %{token | id_token: build_id_token(user)}
      false -> token
    end
  end

  @spec expires_in :: integer
  defp expires_in, do: Config.auth_token_expires_in()

  @spec by_app(Ecto.Queryable.t(), String.t()) :: Ecto.Queryable.t()
  defp by_app(query, app_id), do: from(t in query, where: t.app_id == ^app_id)

  @spec by_access_token(Ecto.Queryable.t(), String.t()) :: Ecto.Queryable.t()
  defp by_access_token(query, access_token) do
    from(t in query, where: t.access_token == ^access_token)
  end

  @spec by_refresh_token(Ecto.Queryable.t(), String.t()) :: Ecto.Queryable.t()
  defp by_refresh_token(query, refresh_token) do
    from(t in query, where: t.refresh_token == ^refresh_token)
  end
end
