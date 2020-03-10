defmodule CPub.Activity do
  @moduledoc """
  Schema for Activity.
  """
  @behaviour Access

  use Ecto.Schema

  import Ecto.Changeset

  alias CPub.{Activity, ActivityPub}
  alias CPub.NS.ActivityStreams, as: AS
  alias CPub.NS.LDP

  @primary_key {:id, CPub.ID, autogenerate: true}
  schema "activities" do
    field :type, RDF.IRI.EctoType

    # Actor who performed activity
    # NOTE: ActivityStreams Vocabulary spec says there can be multiple actors. For now we only allow one.
    field :actor, RDF.IRI.EctoType

    # Recipients of the activity. This includes bcc and bto and should not be made public.
    field :recipients, {:array, RDF.IRI.EctoType}

    field :data, RDF.Description.EctoType

    has_one :object, CPub.Object

    timestamps()
  end

  def new(%RDF.Description{} = activity) do
    %Activity{data: activity}
    |> extract_id
    |> extract_type
    |> extract_actor
    |> extract_recipients
    |> remove_bcc
  end

  def changeset(activity) do
    activity
    |> change()
    |> validate_required([:id, :actor, :data])
    |> unique_constraint(:id, name: "activities_pkey")
    |> validate_activity_type()
    |> CPub.ID.validate()
  end

  defp extract_id(activity) do
    %{activity | id: activity.data.subject}
  end

  defp extract_type(activity) do
    type =
      activity.data
      |> Access.get(RDF.type(), [])
      |> Enum.find(&(&1 in ActivityPub.activity_types()))

    %{activity | type: type}
  end

  defp extract_actor(activity) do
    case activity.data[AS.actor()] do
      [actor] ->
        %{activity | actor: actor}

      _ ->
        activity
    end
  end

  @doc """
  Like `Access.get` but takes a list of keys and returns list of values.
  """
  def get_all(container, keys, default \\ nil) do
    Enum.reduce(keys, [], &[Access.get(container, &1, default) | &2])
  end

  defp extract_recipients(activity) do
    recipients =
      activity.data
      |> get_all([AS.to(), AS.bto(), AS.cc(), AS.bcc(), AS.audience()], [])
      |> Enum.concat()

    %{activity | recipients: recipients}
  end

  defp remove_bcc(activity) do
    data =
      activity.data
      |> RDF.Description.delete_predicates(AS.bto())
      |> RDF.Description.delete_predicates(AS.bcc())

    %{activity | data: data}
  end

  @doc """
  Returns true if description is an ActivityStreams activity, false otherwise.
  """
  def is_activity?(description) do
    Enum.any?(description[RDF.type()], &(&1 in ActivityPub.activity_types()))
  end

  defp validate_activity_type(changeset) do
    if is_activity?(get_field(changeset, :data)) do
      changeset
    else
      add_error(changeset, :data, "not an ActivityPub activity")
    end
  end

  @doc """
  Add objects to a predicate of an `CPub.Activity`.
  """
  def add(%Activity{} = activity, predicate, objects) do
    %{activity | data: RDF.Description.add(activity.data, predicate, objects)}
  end

  @doc """
  Deletes all statements with the given predicates.
  """
  def delete_predicates(%Activity{} = activity, predicates) do
    %{activity | data: RDF.Description.delete_predicates(activity.data, predicates)}
  end

  @doc """
  See `RDF.Description.fetch`.
  """
  @impl Access
  def fetch(%Activity{data: data}, key) do
    Access.fetch(data, key)
  end

  @doc """
  See `RDF.Description.get_and_update`
  """
  @impl Access
  def get_and_update(%Activity{} = activity, key, fun) do
    with {get_value, new_data} <- Access.get_and_update(activity.data, key, fun) do
      {get_value, %{activity | data: new_data}}
    end
  end

  @doc """
  See `RDF.Description.pop`.
  """
  @impl Access
  def pop(%Activity{} = activity, key) do
    case Access.pop(activity.data, key) do
      {nil, _} ->
        {nil, activity}

      {value, new_graph} ->
        {value, %{activity | data: new_graph}}
    end
  end

  @doc """
  Returns the activity as `RDF.Data`.

  If object is loaded it will be included in returned data.
  """
  def to_rdf(activity) do
    activity_description =
      RDF.Description.add(activity.data, AS.published(), activity.inserted_at)

    case activity.object do
      %CPub.Object{} = object ->
        RDF.Data.merge(activity_description, object.data)

      _ ->
        activity_description
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
      |> RDF.Graph.add(id, RDF.type(), LDP.BasicContainer)
      |> RDF.Graph.add(id, RDF.type(), AS.Collection),
      fn activity, graph ->
        graph
        |> RDF.Graph.add(id, LDP.member(), activity.id)
        |> RDF.Graph.add(id, AS.items(), activity.id)
        |> RDF.Data.merge(to_rdf(activity))
      end
    )
  end
end
