defmodule CPub.Objects.Object do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, CPub.ID, autogenerate: true}
  @foreign_key_type :binary_id
  schema "objects" do
    field :data, :map
    timestamps()
  end

  @doc false
  def changeset(object, attrs) do
    object
    |> cast(attrs, [:data])
    |> validate_required([:data])
  end

end
