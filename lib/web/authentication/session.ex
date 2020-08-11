defmodule CPub.Web.Authentication.Session do
  @moduledoc """
  Session that is stored in `Plug.Session` storage for locally authenticated users.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias CPub.Repo

  alias CPub.User

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "authentication_sessions" do
    # session is associated with a user
    belongs_to :user, User, type: :binary_id

    # last time the session was used
    field :last_activity, :utc_datetime

    # TODO: add information on browser user agent. This helps users identify which session is which.

    timestamps()
  end

  def changeset(%__MODULE__{} = session, attrs) do
    session
    |> cast(attrs, [:user_id, :last_activity])
    |> validate_required([:user_id, :last_activity])
    |> assoc_constraint(:user)
    |> unique_constraint(:id, name: "authentication_sessions_pkey")
  end

  def create(%User{} = user) do
    %__MODULE__{}
    |> changeset(%{user_id: user.id, last_activity: DateTime.utc_now()})
    |> Repo.insert()
  end
end
