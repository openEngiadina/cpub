defmodule CPub.ActivityPub.Actor do
  @moduledoc """
  `Ecto.Schema` for ActivityPub Actor
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias CPub.ActivityPub.Actor
  alias CPub.LDP.RDFSource

  alias CPub.NS.ActivityStreams, as: AS
  alias CPub.NS.LDP

  @behaviour Access

  @primary_key {:id, CPub.ID, autogenerate: true}
  @foreign_key_type :binary_id
  schema "ldp_rs" do
    field :data, RDF.Description.EctoType

    many_to_many :authorizations, CPub.WebACL.Authorization,
      join_through: "authorizations_resources",
      join_keys: [resource_id: :id, authorization_id: :id]

    timestamps()
  end

  @doc """
  Returns a new Actor.

  ## Examples

    iex> CPub.ActivityPub.Actor.new()
    %Actor{}

    iex> CPub.ActivityPub.Actor.new(id: ~I<http://social.example/alyssa>, type: ~I<http://www.w3.org/ns/activitystreams#Person>)
    %Actor{}

  """
  def new(opts \\ []) do
    type = Keyword.get(opts, :type, AS.Person)
    id = Keyword.get(opts, :id, CPub.ID.generate(type: :actor))
    description = Keyword.get(opts, :description,
      RDF.Description.new(id)
      |> RDF.Description.add(RDF.type, type))
    %Actor{id: description.subject,
           data: description}
  end

  @doc false
  def changeset(actor \\ new()) do
    actor
    |> RDFSource.changeset
    |> validate_actor_type()
    |> validate_required_property(LDP.inbox, "no inbox")
    |> validate_required_property(AS.outbox, "no outbox")
    # |> validate_required_property(AS.following, "no following")
    # |> validate_required_property(AS.followers, "no followers")
    # |> validate_required_property(AS.liked, "no liked")
  end

  @doc """
  List of all ActivityStreams Actor types.
  """
  def actor_types, do: [AS.Application, AS.Group, AS.Organization, AS.Person, AS.Service] |> Enum.map(&RDF.iri/1)

  @doc """
  Returns true if description is an ActivityStreams actor, false otherwise.
  """
  def is_actor?(description) do
    case description[RDF.type] do
      nil ->
        false
      types ->
        types
        |> Enum.any?(&(&1 in actor_types()))
    end
  end

  defp validate_actor_type(changeset) do
    if is_actor?(get_field(changeset, :data)) do
      changeset
    else
      changeset
      |> add_error(:data, "not an ActivityPub actor")
    end
  end

  def validate_required_property(changeset, property, message) do
    if is_nil(get_field(changeset, :data)[property]) do
      changeset
      |> add_error(:data, message)
    else
      changeset
    end
  end

  @doc """
  See `RDF.Description.fetch`.
  """
  @impl Access
  def fetch(%Actor{data: data}, key) do
    Access.fetch(data, key)
  end

  @doc """
  See `RDF.Description.get_and_update`
  """
  @impl Access
  def get_and_update(%Actor{} = activity, key, fun) do
    with {get_value, new_data} <- Access.get_and_update(activity.data, key, fun) do
      {get_value, %{activity | data: new_data}}
    end
  end

  @doc """
  See `RDF.Description.pop`.
  """
  @impl Access
  def pop(%Actor{} = activity, key) do
    case Access.pop(activity.data, key) do
      {nil, _} ->
        {nil, activity}

      {value, new_graph} ->
        {value, %{activity | data: new_graph}}
    end
  end

  @doc """
  Add objects to a predicate of the actor.

  See also `RDF.Description.add`.
  """
  def add(%Actor{} = actor, predicate, objects) do
    %{actor | data: actor.data |> RDF.Description.add(predicate, objects)}
  end

end
