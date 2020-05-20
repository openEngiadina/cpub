defmodule CPub.Object do
  @moduledoc """
  Schema for objects.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias CPub.{Activity, ID}

  @type t :: %__MODULE__{
          id: RDF.IRI.t() | nil,
          data: RDF.Description.t() | nil,
          activity_id: RDF.IRI.t() | nil
        }

  @primary_key {:id, ID, autogenerate: true}
  schema "objects" do
    field :data, RDF.Description.EctoType

    # Activity that caused creation of this Object
    belongs_to :activity, Activity, type: ID

    timestamps()
  end

  @spec create_changeset(t) :: Ecto.Changeset.t()
  def create_changeset(%__MODULE__{} = object) do
    object
    |> change
    |> ID.validate()
    |> validate_required([:id, :data, :activity_id])
    |> assoc_constraint(:activity)
    |> unique_constraint(:id, name: "objects_pkey")
  end

  @spec new(map) :: t
  def new(%{activity_id: activity_id} = attrs) do
    id = Map.get(attrs, :id, ID.generate())
    data = Map.get(attrs, :data, RDF.Description.new(id))

    %__MODULE__{id: id, data: data, activity_id: activity_id}
  end
end
