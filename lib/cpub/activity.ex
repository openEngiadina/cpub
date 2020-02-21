defmodule CPub.Activity do

  use Ecto.Schema
  import Ecto.Changeset

  alias CPub.ActivityPub
  alias CPub.NS.ActivityStreams, as: AS

  @behaviour Access

  alias CPub.Activity

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
    %{activity |
      id: activity.data.subject}
  end

  defp extract_type(activity) do
    %{activity |
      type: activity.data
      |> Access.get(RDF.type, [])
      |> Enum.find(&(&1 in ActivityPub.activity_types))}
  end

  defp extract_actor(activity) do
    case activity.data[AS.actor] do

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
    keys
    |> Enum.reduce([], &([Access.get(container, &1, default) | &2]))
  end

  defp extract_recipients(activity) do
    %{activity |
      recipients: activity.data
      |> get_all([AS.to, AS.bto, AS.cc, AS.bcc, AS.audience], [])
      |> Enum.concat
    }
  end

  defp remove_bcc(activity) do
    %{activity |
      data: activity.data
      |> RDF.Description.delete_predicates(AS.bto)
      |> RDF.Description.delete_predicates(AS.bcc)}
  end

  @doc """
  Returns true if description is an ActivityStreams activity, false otherwise.
  """
  def is_activity?(description) do
    description[RDF.type]
    |> Enum.any?(&(&1 in ActivityPub.activity_types))
  end

  defp validate_activity_type(changeset) do
    if is_activity?(get_field(changeset, :data)) do
      changeset
    else
      changeset
      |> add_error(:data, "not an ActivityPub activity")
    end
  end

  @doc """
  Add objects to a predicate of an `CPub.Activity`.
  """
  def add(%Activity{} = activity, predicate, objects) do
    %{activity |
      data: activity.data
      |> RDF.Description.add(predicate, objects)}
  end

  @doc """
  Deletes all statements with the given predicates.
  """
  def delete_predicates(%Activity{} = activity, predicates) do
    %{activity |
      data: activity.data
      |> RDF.Description.delete_predicates(predicates)}
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
      activity.data
      |> RDF.Description.add(AS.published, activity.inserted_at)

    case activity.object do
      %CPub.Object{} = object ->
        activity_description
        |> RDF.Data.merge(object.data)

      _ ->
        activity_description
    end
  end

end
