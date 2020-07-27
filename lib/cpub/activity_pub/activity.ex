defmodule CPub.ActivityPub.Activity do
  @moduledoc """
  This defines an `Ecto.Schema` for an ActivityStreams Activity.

  A `CPub.ActivityPub.Activity` serves as an index for `CPub.Object`s that are activities.

  TODO: Currently mutliple activities are allowed that refer the same activity_object. Maybe better if this is not so.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias CPub.Object

  alias CPub.NS.ActivityStreams, as: AS
  alias CPub.NS.LDP

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "activities" do
    # Actor who performed activity
    # NOTE: ActivityStreams Vocabulary spec says there can be multiple actors. For now we only allow one.
    field :actor, RDF.IRI.EctoType

    # Recipients of the activity. This includes bcc and bto and should not be made public.
    field :recipients, {:array, RDF.IRI.EctoType}

    # the Activity object
    belongs_to :activity_object, Object, type: RDF.IRI.EctoType

    # optional object attached to Activity
    belongs_to :object, Object, type: RDF.IRI.EctoType

    timestamps()
  end

  def changeset(%__MODULE__{} = activity, attrs) do
    activity
    |> cast(attrs, [:actor, :recipients, :activity_object_id, :object_id])
    |> validate_required([:actor, :recipients, :activity_object_id])
    |> assoc_constraint(:object)
    |> unique_constraint(:id, name: "activities_pkey")
  end

  @doc """
  Returns the activity as `RDF.Data`.

  If object is loaded it will be included in returned data.
  """
  def to_rdf(%__MODULE__{} = activity) do
    graph =
      RDF.Graph.new()
      |> RDF.Graph.add(activity.activity_object |> RDF.Data.statements())

    case activity.object do
      %Object{} = object ->
        graph
        |> RDF.Graph.add(object |> RDF.Data.statements())

      _ ->
        graph
    end
  end

  @doc """
  Returns a RDF.Graph containing a list of Activities in a ldp:Container and in
  an as:Collection.
  """
  def as_container(activities, id) do
    activities
    |> Enum.reduce(
      RDF.Graph.new()
      |> RDF.Graph.add(id, RDF.type(), RDF.iri(LDP.BasicContainer))
      |> RDF.Graph.add(id, RDF.type(), RDF.iri(AS.Collection)),
      fn activity, graph ->
        graph
        |> RDF.Graph.add(id, LDP.member(), activity.activity_object_id)
        |> RDF.Graph.add(id, AS.items(), activity.activity_object_id)
        |> RDF.Data.merge(to_rdf(activity))
      end
    )
  end
end
