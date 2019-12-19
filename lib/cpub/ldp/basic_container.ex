defmodule CPub.LDP.BasicContainer do
  @moduledoc """
  Linked Data Platform Basic Container

  Containers are LDP Resources that contain other resources.

  `CPub.LDP.BasicContainer` is an `Ecto.Schema` and implements the `Enumerable` protocol.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias CPub.LDP.BasicContainer
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
  def new(opts \\ []) do
    id = Keyword.get(opts, :id, CPub.ID.generate(type: :container))
    %BasicContainer{id: id,
                    data: Description.new(id)
                    |> Description.add(RDF.type, LDP.BasicContainer)}
  end

  @doc false
  def changeset(container \\ %BasicContainer{}) do
    container
    |> change()
    # NOTE forcing the change might be slightly unconventional. I think it is justified as this is the only field in the schema and optimizing by selecting which field get a change does not make sense.
    |> force_change(:data, container.data)
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
  Add an element to the container.
  """
  def add(%BasicContainer{} = container, %RDF.IRI{} = element) do
    %{container | data: container.data |> RDF.Description.add(LDP.contains, element)}
  end

  def to_list(%BasicContainer{} = container) do
    case container.data
    |> RDF.Description.fetch(LDP.contains)
      do
      :error -> []

      count -> count
    end
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
