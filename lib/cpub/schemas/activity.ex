defmodule CPub.Activity do
  @moduledoc """
  Schema for Activity.
  """

  @behaviour Access

  use Ecto.Schema

  import Ecto.Changeset

  alias CPub.{ActivityPub, ID, Object}
  alias CPub.NS.ActivityStreams, as: AS
  alias CPub.NS.LDP

  @type t :: %__MODULE__{
          id: RDF.IRI.t() | nil,
          type: RDF.IRI.t() | nil,
          actor: RDF.IRI.t() | nil,
          recipients: [RDF.IRI.t()] | nil,
          data: RDF.Description.t() | nil
        }

  @primary_key {:id, CPub.ID, autogenerate: true}
  schema "activities" do
    field :type, RDF.IRI.EctoType

    # Actor who performed activity
    # NOTE: ActivityStreams Vocabulary spec says there can be multiple actors. For now we only allow one.
    field :actor, RDF.IRI.EctoType

    # Recipients of the activity. This includes bcc and bto and should not be made public.
    field :recipients, {:array, RDF.IRI.EctoType}

    field :data, RDF.Description.EctoType

    has_one :object, Object

    timestamps()
  end

  @spec create_changeset(t) :: Ecto.Changeset.t()
  def create_changeset(%__MODULE__{} = activity) do
    activity
    |> change()
    |> validate_required([:id, :actor, :data])
    |> unique_constraint(:id, name: "activities_pkey")
    |> validate_activity_type()
    |> ID.validate()
  end

  @spec validate_activity_type(Ecto.Changeset.t()) :: Ecto.Changeset.t()
  defp validate_activity_type(changeset) do
    if is_activity?(get_field(changeset, :data)) do
      changeset
    else
      add_error(changeset, :data, "not an ActivityPub activity")
    end
  end

  @spec new(RDF.Description.t()) :: t
  def new(%RDF.Description{} = activity) do
    %__MODULE__{data: activity}
    |> extract_id
    |> extract_type
    |> extract_actor
    |> extract_recipients
    |> remove_bcc
  end

  @spec extract_id(t) :: t
  defp extract_id(%__MODULE__{} = activity) do
    %{activity | id: activity.data.subject}
  end

  @spec extract_type(t) :: t
  defp extract_type(%__MODULE__{} = activity) do
    type =
      activity.data
      |> Access.get(RDF.type(), [])
      |> Enum.find(&(&1 in ActivityPub.activity_types()))

    %{activity | type: type}
  end

  @spec extract_actor(t) :: t
  defp extract_actor(%__MODULE__{} = activity) do
    case activity.data[AS.actor()] do
      [actor] ->
        %{activity | actor: actor}

      _ ->
        activity
    end
  end

  @spec extract_recipients(t) :: t
  defp extract_recipients(%__MODULE__{} = activity) do
    recipients =
      activity.data
      |> get_all([AS.to(), AS.bto(), AS.cc(), AS.bcc(), AS.audience()], [])
      |> Enum.concat()

    %{activity | recipients: recipients}
  end

  @spec remove_bcc(t) :: t
  defp remove_bcc(%__MODULE__{} = activity) do
    data =
      activity.data
      |> RDF.Description.delete_predicates(AS.bto())
      |> RDF.Description.delete_predicates(AS.bcc())

    %{activity | data: data}
  end

  @spec get_all(RDF.Description.t(), [RDF.IRI.t()], any) :: [any]
  defp get_all(container, keys, default) do
    Enum.map(keys, &Access.get(container, &1, default))
  end

  @doc """
  Returns true if description is an ActivityStreams activity, false otherwise.
  """
  @spec is_activity?(RDF.Description.t()) :: boolean
  def is_activity?(description) do
    Enum.any?(description[RDF.type()] || [], &(&1 in ActivityPub.activity_types()))
  end

  @doc """
  Add objects to a predicate of an `CPub.Activity`.
  """
  @spec add(
          t,
          RDF.Statement.coercible_predicate(),
          RDF.Statement.coercible_object() | [RDF.Statement.coercible_object()]
        ) :: t
  def add(%__MODULE__{} = activity, predicate, objects) do
    %{activity | data: RDF.Description.add(activity.data, predicate, objects)}
  end

  @doc """
  Deletes all statements with the given predicates.
  """
  @spec delete_predicates(
          t,
          RDF.Statement.coercible_predicate() | [RDF.Statement.coercible_predicate()]
        ) :: t
  def delete_predicates(%__MODULE__{} = activity, predicates) do
    %{activity | data: RDF.Description.delete_predicates(activity.data, predicates)}
  end

  @doc """
  See `RDF.Description.fetch`.
  """
  @impl Access
  @spec fetch(t, atom) :: {:ok, any} | :error
  def fetch(%__MODULE__{data: data}, key) do
    Access.fetch(data, key)
  end

  @doc """
  See `RDF.Description.get_and_update`
  """
  @impl Access
  @spec get_and_update(t, atom, fun) :: {any, t}
  def get_and_update(%__MODULE__{} = activity, key, fun) do
    with {get_value, new_data} <- Access.get_and_update(activity.data, key, fun) do
      {get_value, %{activity | data: new_data}}
    end
  end

  @doc """
  See `RDF.Description.pop`.
  """
  @impl Access
  @spec pop(t, atom) :: {any | nil, t}
  def pop(%__MODULE__{} = activity, key) do
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
  @spec to_rdf(t) :: RDF.Description.t()
  def to_rdf(%__MODULE__{} = activity) do
    activity_description =
      RDF.Description.add(activity.data, AS.published(), activity.inserted_at)

    case activity.object do
      %Object{} = object ->
        RDF.Data.merge(activity_description, object.data)

      _ ->
        activity_description
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
