defmodule CPub.Objects.Object do
  use Ecto.Schema
  import Ecto.Changeset

  alias CPub.Objects.Object

  @behaviour Access

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


  @doc """
  See `RDF.Graph.fetch`.
  """
  @impl Access
  def fetch(%Object{data: data}, key) do
    Access.fetch(data, key)
  end

  @doc """
  See `RDF.Graph.get_and_update`
  """
  @impl Access
  def get_and_update(%Object{} = object, key, fun) do
    with {get_value, new_graph} <- Access.get_and_update(object.data, key, fun) do
      {get_value, %{object | data: new_graph}}
    end
  end

  @doc """
  See `RDF.Graph.pop`.
  """
  @impl Access
  def pop(%Object{} = object, key) do
    case Access.pop(object.data, key) do
      {nil, _} ->
        {nil, object}

      {value, new_graph} ->
        {value, %{object | data: new_graph}}
    end
  end

end
