defmodule CPub.Object do
  use Ecto.Schema
  import Ecto.Changeset

  alias CPub.Object

  @primary_key {:id, CPub.ID, autogenerate: true}
  schema "objects" do
    field :data, RDF.Description.EctoType

    # Activity that caused creation of this Object
    belongs_to :activity, CPub.Activity, type: CPub.ID

    timestamps()
  end

  def new(opts \\ []) do
    id = Keyword.get(opts, :id, CPub.ID.generate())
    data = Keyword.get(opts, :data, RDF.Description.new(id))
    activity_id = Keyword.get(opts, :activity_id)

    %Object{id: id, data: data, activity_id: activity_id}
  end

  def changeset(%Object{} = object) do
    object
    |> change
    |> CPub.ID.validate()
    |> validate_required([:id, :data, :activity_id])
    |> assoc_constraint(:activity)
    |> unique_constraint(:id, name: "objects_pkey")
  end
end
