defmodule CPub.Registration do
  @moduledoc """
  Schema for CPub user registration.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias CPub.{Repo, User}

  @type t :: %__MODULE__{
          username: String.t() | nil,
          provider: String.t() | nil,
          info: map | nil
        }

  schema "registrations" do
    field :username, :string
    field :provider, :string
    field :info, :map, default: %{}

    belongs_to(:user, User, type: CPub.ID)

    timestamps()
  end

  @spec create_changeset(t, map) :: Ecto.Changeset.t()
  defp create_changeset(%__MODULE__{} = registration, attrs) do
    registration
    |> cast(attrs, [:user_id, :username, :provider, :info])
    |> validate_required([:username, :provider])
    |> foreign_key_constraint(:user_id)
    |> unique_constraint(:username, name: :registrations_username_provider_index)
  end

  @spec create(map) :: {:ok, t} | {:error, Ecto.Changeset.t()}
  def create(attrs) do
    %__MODULE__{}
    |> create_changeset(attrs)
    |> Repo.insert()
  end

  @spec bind_to_user(t, User.t()) :: {:ok, t} | {:error, Ecto.Changeset.t()}
  def bind_to_user(%__MODULE__{} = registration, %User{id: user_id}) do
    registration
    |> create_changeset(%{user_id: user_id})
    |> Repo.update()
  end

  @spec get_by(map) :: t | nil
  def get_by(attrs) do
    Repo.get_by(__MODULE__, attrs)
  end

  @spec get_or_create(map, map) :: {:ok, t} | {:error, Ecto.Changeset.t()}
  def get_or_create(attrs, info) do
    case get_by(attrs) do
      %__MODULE__{} = registration ->
        {:ok, registration}

      nil ->
        create(Map.put(attrs, :info, info))
    end
  end
end
