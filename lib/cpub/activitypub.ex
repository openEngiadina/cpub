defmodule CPub.ActivityPub do
  @moduledoc """
  ActivityPub context
  """

  alias Ecto.Multi
  alias Ecto.Changeset

  alias CPub.ActivityPub.Activity
  alias CPub.Objects.Object
  alias CPub.NS.ActivityStreams
  alias CPub.Repo

  alias RDF.Description
  alias RDF.Graph

  @activitystreams RDF.Turtle.read_file!("./priv/vocabs/activitystreams2.ttl")
  @doc """
  The ActivityStreams 2.0 ontology
  """
  def activitystreams, do: @activitystreams

  @activity_types (SPARQL.execute_query(@activitystreams,
    SPARQL.query("""
    select ?activity_type
    where {
      ?activity_type rdfs:subClassOf as:Activity .
    }
    """
    ))).results |> Enum.map(&(&1["activity_type"]))
  @doc """
  List of all ActivityStreams Activity types
  """
  def activity_types, do: @activity_types

  @doc """
  Creates an ActivityPub activity, computes side-effects and runs everything in a transaction.
  """
  def create(%Description{subject: activity_id} = activity, data \\ RDF.Graph.new) do
    # generate an id for an object that may be created
    object_id = CPub.ID.generate()

    # create the changeset to add the activity
    activity_changeset =
      Activity.changeset(%{data: activity, id: activity_id})
      # set the object id if it is a create activity
      |> Changeset.update_change(:data, &(set_object_id_if_create_activity(&1, object_id)))

    # create a transaction
    Multi.new

    # insert the activity
    |> Multi.insert(:activity, activity_changeset)

    # insert the object (if a Create activity)
    |> create_object(activity, object_id, data)

    # run the transaction
    |> Repo.transaction
  end

  defp set_object_id_if_create_activity(activity, object_id) do
    if RDF.iri(ActivityStreams.Create) in activity[RDF.type] do
      activity
      |> Description.delete_predicates(ActivityStreams.object)
      |> Description.add(ActivityStreams.object, object_id)
    else
      # don't do anything if not a Create activity
      activity
    end
  end

  # Creates an object if it is a Create activity
  defp create_object(multi, %Description{subject: activity_id} = activity, object_id, data) do
    if RDF.iri(ActivityStreams.Create) in activity[RDF.type] do
      case data[activity_id][ActivityStreams.object] do

        [original_object_id] ->
          # replace subject
          multi
          |> Multi.insert(:object,
          Object.changeset(%{id: object_id,
                             data: data
                             # remove the activity description and the original object description
                             |> Graph.delete_subjects([original_object_id, activity_id])
                             # replace subject of object with new id and add to graph
                             |> Graph.add(%{data[original_object_id] | subject: object_id})}))

        _ ->
          multi
          |> Multi.error(:object, "could not find object")
      end
    else
      multi
    end
  end

end
