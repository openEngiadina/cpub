defmodule CPub.LDP.BasicContainer do
  @moduledoc """
  Linked Data Platform Basic Container

  Containers are LDP Resources that contain other resources.

  `CPub.LDP.BasicContainer` is an `Ecto.Schema` and implements the `Enumerable` protocol.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias CPub.LDP.BasicContainer

  alias CPub.Repo
  alias CPub.NS.LDP

  alias RDF.Description

  @primary_key {:id, CPub.ID, autogenerate: true}
  @foreign_key_type :binary_id
  schema "objects" do
    field :data, RDF.Description.EctoType
    timestamps()
  end

  @doc """
  Returns a new Basic Container.
  """
  def new(id \\ CPub.ID.generate) do
    %BasicContainer{id: id,
                    data: Description.new(id) |> Description.add(RDF.type, LDP.BasicContainer)}
  end

  @doc false
  def changeset(container \\ %BasicContainer{}, attrs) do
    container
    |> cast(attrs, [:id, :data])
    |> CPub.ID.validate()
    |> validate_required([:id, :data])
    |> validate_type()
    |> unique_constraint(:id, name: "objects_pkey")
  end

  @doc """
  Returns true if description is a LDP Basic Container, false otherwise.
  """
  def is_basic_container?(description) do
    case description[RDF.type] do
      nil ->
        false
      types ->
        types
        |> Enum.any?(&(&1 == RDF.iri(LDP.BasicContainer)))
    end
  end

  defp validate_type(changeset) do
    if is_basic_container?(get_field(changeset, :data)) do
      changeset
    else
      changeset
      |> add_error(:data, "not a LDP.BasicContainer")
    end
  end

  @doc """
  Creates an empty container and return the changeset to insert the newly created container.
  """
  def create_changeset(id \\ CPub.ID.generate()) do
    RDF.Description.new(id)
    |> RDF.Description.add(RDF.type, LDP.BasicContainer)
    |> (&(changeset(%{data: &1, id: id}))).()
  end

  @doc """
  Creates an empty container. If not id is specified an id will be generated.
  """
  def create(id \\ CPub.ID.generate()) do
    create_changeset(id)
    |> Repo.insert()
  end

  @doc """
  Gets a container.

  Raises `Ecto.NoResultsError` if the Container does not exist.
  """
  def get!(id) do
    Repo.get!(BasicContainer, id)
  end

  @doc """
  Returns the changeset that would add a single element to the container.
  """
  def add_changeset(%BasicContainer{} = container, %RDF.IRI{} = element) do
    container
    |> changeset(%{
          data: container.data
          |> RDF.Description.add(LDP.contains, element)})
  end

  def add_changeset(%RDF.IRI{} = container_id, element) do
    get!(container_id)
    |> add_changeset(element)
  end

  @doc """
  Adds an element to the container and writes update to database.
  """
  def add(container, %RDF.IRI{} = element) do
    add_changeset(container, element)
    |> Repo.update()
  end

  def to_list(%BasicContainer{} = container) do
    case container.data
    |> RDF.Description.fetch(LDP.contains)
      do
      :error -> []

      count -> count
    end
  end

  def to_list(%RDF.IRI{} = container_id) do
    get!(container_id)
    |> to_list()
  end

  def contains?(container, element) do
    container.data
    |> RDF.Description.include?({LDP.contains, element})
  end

  defimpl Enumerable do
    def member?(container, element),
      do: {:ok, BasicContainer.contains?(container, element)}

    def count(container) do
      {:ok,
       container
       |> BasicContainer.to_list
       |> Enum.count}
    end

    def slice(_container), do: {:error, __MODULE__}

    def reduce(%BasicContainer{} = container, acc, fun) do
      container.data
      |> Enum.reduce(acc, fun)
    end

  end

end
