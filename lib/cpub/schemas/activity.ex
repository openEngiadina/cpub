defmodule CPub.Activity do
  @moduledoc """
  Schema for Activity.
  """

  @behaviour Access

  use Ecto.Schema

  import Ecto.Changeset

  alias CPub.{ActivityPub, Object}
  alias CPub.NS.ActivityStreams, as: AS
  alias CPub.NS.LDP

  @type t :: %__MODULE__{
          id: RDF.IRI.t() | nil,
          type: RDF.IRI.t() | nil,
          actor: RDF.IRI.t() | nil,
          recipients: [RDF.IRI.t()] | nil,
          activity_object_id: RDF.IRI.t() | nil,
          object_id: RDF.IRI.t() | nil
        }

  @primary_key {:id, RDF.IRI.EctoType, []}
  schema "activities" do
    field :type, RDF.IRI.EctoType

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

  @spec create_changeset(t) :: Ecto.Changeset.t()
  def create_changeset(%__MODULE__{} = activity) do
    activity
    |> change()
    |> validate_required([:id, :actor, :activity_object])
    |> unique_constraint(:id, name: "activities_pkey")
    |> validate_activity_type()
  end

  @spec validate_activity_type(Ecto.Changeset.t()) :: Ecto.Changeset.t()
  defp validate_activity_type(changeset) do
    case is_activity?(get_field(changeset, :activity_object)) do
      true -> changeset
      false -> add_error(changeset, :activity_object, "not an ActivityPub activity")
    end
  end

  @spec new(Object.t(), Object.t() | nil) :: t
  def new(%Object{} = activity, %Object{} = object) do
    %__MODULE__{activity_object: activity, object: object}
    |> extract_id
    |> extract_type
    |> extract_actor
    |> extract_recipients
  end

  @spec extract_id(t) :: t
  defp extract_id(%__MODULE__{} = activity) do
    %{activity | id: activity.activity_object.id}
  end

  @spec extract_type(t) :: t
  defp extract_type(%__MODULE__{} = activity) do
    type =
      activity.activity_object[:base_subject]
      |> Access.get(RDF.type(), [])
      |> Enum.find(&(&1 in ActivityPub.activity_types()))

    %{activity | type: type}
  end

  @spec extract_actor(t) :: t
  defp extract_actor(%__MODULE__{} = activity) do
    case activity.activity_object[:base_subject][AS.actor()] do
      [actor] -> %{activity | actor: actor}
      _ -> activity
    end
  end

  @spec extract_recipients(t) :: t
  defp extract_recipients(%__MODULE__{} = activity) do
    recipients =
      activity.activity_object[:base_subject]
      |> get_all([AS.to(), AS.bto(), AS.cc(), AS.bcc(), AS.audience()], [])
      |> Enum.concat()

    %{activity | recipients: recipients}
  end

  @spec get_all(RDF.Description.t(), [RDF.IRI.t()], any) :: [any]
  defp get_all(container, keys, default) do
    Enum.map(keys, &Access.get(container, &1, default))
  end

  @doc """
  Returns true if description is an ActivityStreams activity, false otherwise.
  """
  @spec is_activity?(RDF.FragmentGraph.t()) :: boolean
  def is_activity?(fg) do
    Enum.any?(fg[:base_subject][RDF.type()] || [], &(&1 in ActivityPub.activity_types()))
  end

  @doc """
  See `RDF.Description.fetch`.
  """
  @impl Access
  @spec fetch(t, atom) :: {:ok, any} | :error
  def fetch(%__MODULE__{} = activity, key) do
    Access.fetch(activity |> to_rdf, key)
  end

  @impl Access
  @spec get_and_update(t, atom, fun) :: {any, t}
  def get_and_update(%__MODULE__{} = _activity, _key, _fun) do
    # TODO
    raise "not implemented"
  end

  @doc """
  See `RDF.Description.pop`.
  """
  @impl Access
  @spec pop(t, atom) :: {any | nil, t}
  def pop(%__MODULE__{} = _activity, _key) do
    # TODO
    raise "not implemented"
  end

  @doc """
  Returns the activity as `RDF.Data`.

  If object is loaded it will be included in returned data.
  """
  @spec to_rdf(t) :: RDF.Graph.t()
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
  @spec as_container([t], RDF.IRI.t()) :: RDF.Graph.t()
  def as_container(activities, id) do
    activities
    |> Enum.reduce(
      RDF.Graph.new()
      |> RDF.Graph.add(id, RDF.type(), RDF.iri(LDP.BasicContainer))
      |> RDF.Graph.add(id, RDF.type(), RDF.iri(AS.Collection)),
      fn activity, graph ->
        graph
        |> RDF.Graph.add(id, LDP.member(), activity.id)
        |> RDF.Graph.add(id, AS.items(), activity.id)
        |> RDF.Data.merge(to_rdf(activity))
      end
    )
  end
end
