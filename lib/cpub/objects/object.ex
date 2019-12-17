defmodule CPub.Objects.Object do
  use Ecto.Schema
  import Ecto.Changeset

  alias CPub.Objects.Object

  @primary_key {:id, CPub.ID, autogenerate: true}
  @foreign_key_type :binary_id
  schema "objects" do

    # data field holds an RDF graph
    field :data, RDF.Graph.EctoType

    timestamps()
  end

  @doc false
  def changeset(object \\ %Object{}, attrs) do
    object
    |> cast(attrs, [:id, :data])
    |> CPub.ID.validate
    |> validate_required([:id, :data])
    |> unique_constraint(:id, name: "objects_pkey")
  end

end
