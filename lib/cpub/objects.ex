defmodule CPub.Objects do
  @moduledoc """
  The Objects context.
  """

  import Ecto.Query, warn: false
  alias CPub.Repo

  alias CPub.Objects.Object
  alias CPub.ActivityPub.Actor
  alias CPub.LDP.BasicContainer

  alias CPub.NS.LDP

  def list_objects do
    Repo.all(Object)
  end

  def get_object!(id) do
    Repo.get!(Object, id)
  end

  def create_object(attrs \\ %{}) do
    %Object{}
    |> Object.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Add an element to an object if it is a container or an actor.

  If object is an actor, element will be added to the inbox of the actor.

  Returns a changeset if element can be added, {:error, object} otherwise.

  TODO pack this functionality in a Protocol
  """
  def add_to_container(object, element)
  def add_to_container(%RDF.IRI{} = id, element) do
    Repo.get(Object, id)
    |> add_to_container(element)
  end

  def add_to_container(%Object{} = object, element) do
    cond do
      Actor.is_actor? object.data[object.id] ->
        object[object.id][LDP.inbox]
        |> List.first()
        |> add_to_container(element)

      BasicContainer.is_basic_container? object.data[object.id] ->
        %BasicContainer{id: object.id, data: object.data[object.id]}
        |> BasicContainer.add(element)
        |> BasicContainer.changeset()

      true ->
        {:error, object}
    end
  end

end
