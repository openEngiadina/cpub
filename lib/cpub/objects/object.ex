defmodule CPub.Objects.Object do
  use Ecto.Schema
  import Ecto.Changeset

  alias CPub.Objects.Object

  @primary_key {:id, CPub.ID, autogenerate: true}
  @foreign_key_type :binary_id
  schema "objects" do
    field :data, RDF.EctoType
    timestamps()
  end

  @doc false
  def changeset(object \\ %Object{}, attrs) do
    object
    |> cast(attrs, [:id, :data])
    |> autogenerate_id
    |> validate_required([:id, :data])
    |> unique_constraint(:id, name: "objects_pkey")
  end

  defp autogenerate_id(changeset) do
    if is_nil(get_field(changeset, :id)) do
      changeset
      |> put_change(:id, CPub.ID.generate)
    else
      changeset
    end
  end

end
