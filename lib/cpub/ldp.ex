defmodule CPub.LDP do
  @moduledoc """
  Linked Data Platform context
  """

  alias CPub.LDP.BasicContainer
  alias CPub.LDP.RDFSource
  alias CPub.ActivityPub.Actor

  alias CPub.Repo

  @doc """
  Creates an empty container.
  """
  def create_basic_container(opts \\ []) do
    BasicContainer.new(opts)
    |> BasicContainer.changeset()
    |> Repo.insert()
  end

  @doc """
  Gets a single BasicContainer.

  Raises `Ecto.NoResultsError` if the BasicContainer does not exist.
  """
  def get_basic_container!(id), do: Repo.get!(BasicContainer, id)

  @doc """
  Gets a single RDFSource.
  """
  def get_rdf_source!(id), do: Repo.get!(RDFSource, id)

  @doc """
  Returns a list of all RDF sources.
  """
  def list_rdf_source(), do: Repo.all(RDFSource)

  @doc """
  Create an RDFSOurce
  """
  def create_rdf_source(opts \\ []) do
    RDFSource.new(opts)
    |> RDFSource.changeset()
    |> Repo.insert()
  end

  @doc """
  Add an element to a resource.

  If resource is a container, element will be added to container.

  If resource is an ActivityPub.Actor, element will be added to inbox of the actor.

  Returns a changeset if element can be added, {:error, resource} otherwise.
  """
  def add_to_container(resource, element)
  def add_to_container(%RDF.IRI{} = id, element) do
    Repo.get(RDFSource, id)
    |> add_to_container(element)
  end

  def add_to_container(%RDFSource{} = resource, element) do
    cond do
      Actor.is_actor? resource.data[resource.id] ->
        resource[resource.id][CPub.NS.LDP.inbox]
        |> List.first()
        |> add_to_container(element)

      BasicContainer.is_basic_container? resource.data[resource.id] ->
        %BasicContainer{id: resource.id, data: resource.data[resource.id]}
        |> BasicContainer.add(element)
        |> BasicContainer.changeset()

      true ->
        {:error, resource}
    end
  end
end
