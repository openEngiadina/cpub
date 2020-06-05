defmodule CPub.Web.OAuth.Authorization do
  @moduledoc """
  Schema for OAuth authorization.
  """

  use Ecto.Schema

  import Ecto.Changeset
  import Ecto.Query

  alias CPub.{Crypto, Repo, User}
  alias CPub.Web.OAuth.App

  @type t :: %__MODULE__{
          code: String.t() | nil,
          scopes: [String.t()] | nil,
          valid_until: NaiveDateTime.t() | nil,
          used: boolean | nil,
          user_id: RDF.IRI.t() | nil,
          app_id: integer | nil
        }

  schema "oauth_authorizations" do
    field :code, :string
    field :scopes, {:array, :string}, default: []
    field :valid_until, :naive_datetime_usec
    field :used, :boolean, default: false

    belongs_to :user, User, type: CPub.ID
    belongs_to :app, App

    timestamps()
  end

  @spec create_changeset(map) :: Ecto.Changeset.t()
  defp create_changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, [:scopes, :valid_until, :user_id, :app_id])
    |> validate_required([:app_id, :scopes])
    |> put_code()
    |> put_lifetime()
  end

  @spec put_code(Ecto.Changeset.t()) :: Ecto.Changeset.t()
  defp put_code(changeset) do
    put_change(changeset, :code, Crypto.random_string(32))
  end

  @spec put_lifetime(Ecto.Changeset.t()) :: Ecto.Changeset.t()
  defp put_lifetime(changeset) do
    put_change(changeset, :valid_until, NaiveDateTime.add(NaiveDateTime.utc_now(), 60 * 10))
  end

  @spec use_changeset(t, map) :: Ecto.Changeset.t()
  def use_changeset(%__MODULE__{} = auth, attrs) do
    auth
    |> cast(attrs, [:used])
    |> validate_required([:used])
  end

  @spec create(App.t(), User.t(), [String.t()] | nil) :: {:ok, t} | {:error, Ecto.Changeset.t()}
  def create(%App{} = app, %User{} = user, scopes \\ nil) do
    %{scopes: scopes || app.scopes, user_id: user.id, app_id: app.id}
    |> create_changeset()
    |> Repo.insert()
  end

  @spec use_code(t) :: {:ok, t} | {:error, Ecto.Changeset.t()} | {:error, String.t()}
  def use_code(%__MODULE__{used: false, valid_until: valid_until} = auth) do
    if NaiveDateTime.diff(NaiveDateTime.utc_now(), valid_until) < 0 do
      auth
      |> use_changeset(%{used: true})
      |> Repo.update()
    else
      {:error, "code expired"}
    end
  end

  @spec get_by(map) :: t | nil
  def get_by(attrs) do
    Repo.get_by(__MODULE__, attrs)
  end

  @spec get_by_code(App.t(), String.t()) :: {:ok, t} | {:error, Ecto.Changeset.t()}
  def get_by_code(%App{id: app_id} = _app, code) do
    from(a in __MODULE__, where: a.app_id == ^app_id and a.code == ^code)
    |> Repo.get_one()
  end
end
