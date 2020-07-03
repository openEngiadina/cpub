defmodule CPub.Object do
  @moduledoc """
  An immutable object that holds an `RDF.FragmentGraph`.

  This is a wrapper for `RDF.FragmentGraph` that makes it storable in an `Ecto.Repo`.

  It also implements the `RDF.Data` protocol.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: RDF.IRI.t() | nil,
          content: RDF.FragmentGraph.t() | nil
        }

  @primary_key {:id, RDF.IRI.EctoType, []}
  schema "objects" do
    field :content, RDF.FragmentGraph.EctoType

    timestamps()
  end

  @spec create_changeset(t) :: Ecto.Changeset.t()
  def create_changeset(%__MODULE__{} = object) do
    object
    |> change
    |> validate_required([:id, :content])
    |> unique_constraint(:id, name: "objects_pkey")
  end

  @spec new(RDF.FragmentGraph.t()) :: t
  def new(%RDF.FragmentGraph{base_subject: base_subject} = content) do
    %__MODULE__{id: base_subject, content: content}
  end

  @spec new() :: t
  def new() do
    id = RDF.UUID.generate()
    content = RDF.FragmentGraph.new(id)

    %__MODULE__{id: id, content: content}
  end

  @behaviour Access

  @impl Access
  def fetch(%__MODULE__{content: content}, key), do: Access.fetch(content, key)

  @impl Access
  def pop(%__MODULE__{content: content}, key), do: Access.pop(content, key)

  @impl Access
  def get_and_update(%__MODULE__{content: content}, key, function),
    do: Access.get_and_update(content, key, function)

  defimpl RDF.Data, for: CPub.Object do
    def delete(obj, statements), do: RDF.Data.delete(obj.content, statements)

    def describes?(obj, subject), do: RDF.Data.describes?(obj.content, subject)

    def description(obj, subject), do: RDF.Data.description(obj.content, subject)

    def descriptions(obj), do: RDF.Data.descriptions(obj.content)

    def equal?(obj1, obj2), do: RDF.Data.equal?(obj1.content, obj2)

    def include?(obj, statement), do: RDF.Data.include?(obj.content, statement)

    def merge(obj, data), do: RDF.Data.merge(obj.content, data)

    def objects(obj), do: RDF.Data.objects(obj.content)

    def pop(obj), do: RDF.Data.pop(obj)

    def predicates(obj), do: RDF.Data.predicates(obj.content)

    def resources(obj), do: RDF.Data.resources(obj.content)

    def statement_count(obj), do: RDF.Data.statement_count(obj.content)

    def statements(obj), do: RDF.Data.statements(obj.content)

    def subject_count(obj), do: RDF.Data.subject_count(obj.content)

    def subjects(obj), do: RDF.Data.subjects(obj.content)

    def values(obj), do: RDF.Data.values(obj.content)

    def values(obj, mapping), do: RDF.Data.values(obj.content, mapping)
  end
end
