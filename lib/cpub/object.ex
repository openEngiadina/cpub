defmodule CPub.Object do

  use Ecto.Schema
  import Ecto.Changeset

  alias CPub.Object

  @primary_key {:id, CPub.ID, autogenerate: true}
  schema "objects" do
    field :data, RDF.Description.EctoType
    timestamps()
  end

  def new(opts \\ []) do
    id =  Keyword.get(opts, :id, CPub.ID.generate())
    data = Keyword.get(opts, :data, RDF.Description.new(id))
    %Object{id: id, data: data}
  end

  def changeset(%Object{} = object) do
    object
    |> change
    |> CPub.ID.validate
    |> validate_required([:id, :data])
    |> unique_constraint(:id, name: "objects_pkey")
  end

end
