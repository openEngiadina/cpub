defmodule CPub.Web.Authorization.Token do
  @moduledoc """
  An OAuth 2.0 Token that can be used to access ressources.
  """

  use Ecto.Schema

  import Ecto.Changeset
  alias Ecto.Multi

  alias CPub.Repo
  alias CPub.Web.Authorization.Authorization

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "oauth_server_tokens" do
    field :access_token, :string
    belongs_to :authorization, Authorization, type: :binary_id
    timestamps()
  end

  defp random_token() do
    :crypto.strong_rand_bytes(32)
    |> Base.encode32(padding: false)
  end

  def changeset(%__MODULE__{} = token, attrs) do
    token
    |> cast(attrs, [:authorization_id])
    |> put_change(:access_token, random_token())
    |> validate_required([:access_token, :authorization_id])
    |> assoc_constraint(:authorization)
    |> unique_constraint(:id, name: "oauth_server_tokens_pkey")
    |> unique_constraint(:access_token, name: "oauth_server_tokens_authorization_id_index")
  end

  @doc """
  Creates a new (initial) token for an `Authorization`.
  """
  def create(%Authorization{} = authorization) do
    if authorization.used or Authorization.expired?(authorization) do
      {:error, :invalid_grant, "access code expired or already used"}
    else
      case Multi.new()
           |> Multi.insert(
             :token,
             changeset(%__MODULE__{}, %{authorization_id: authorization.id})
           )
           |> Multi.update(:used_authorization, Authorization.use_changeset(authorization))
           |> Repo.transaction() do
        {:ok, %{token: token}} ->
          {:ok, token}

        _ ->
          {:error, :invalid_grant, "failed to create access token"}
      end
    end
  end

  @doc """
  Creates a refreshed token for an `Authorization`.
  """
  def refresh(%Authorization{} = authorization) do
    case %__MODULE__{}
         |> changeset(%{authorization_id: authorization.id})
         |> Repo.insert() do
      {:ok, token} ->
        {:ok, token}

      _ ->
        {:error, :invalid_grant, "failed to refresh token"}
    end
  end

  @doc """
  Returns the numer of seconds the Token is valid for after creation.
  """
  def valid_for() do
    # 60 days
    60 * 60 * 24 * 60
  end

  @doc """
  Returns true if the Token is expired and can no longer be used to access a ressource.
  """
  def expired?(%__MODULE__{} = token) do
    valid_for() <= NaiveDateTime.diff(NaiveDateTime.utc_now(), token.inserted_at)
  end
end
