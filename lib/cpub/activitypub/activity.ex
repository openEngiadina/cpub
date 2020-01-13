defmodule CPub.ActivityPub.Activity do
  @moduledoc """
  `Ecto.Schema` for ActivityPub activities.

  Validation of activites is done here.

  Splitting up activites into objects and handling activites (delivery, etc.) is done somewhere else.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias CPub.ActivityPub
  alias CPub.ActivityPub.Activity
  alias CPub.LDP.RDFSource

  alias CPub.NS.ActivityStreams, as: AS

  @behaviour Access

  @primary_key {:id, CPub.ID, autogenerate: true}
  @foreign_key_type :binary_id
  schema "ldp_rs" do
    field :data, RDF.Description.EctoType

    has_many :authorizations, CPub.Users.Authorization,
      foreign_key: :resource_id

    timestamps()
  end

  def new(%RDF.Description{} = activity) do
    %Activity{data: activity,
              id: activity.subject}
  end

  @doc false
  def changeset(activity \\ %Activity{}) do
    activity
    |> RDFSource.changeset
    |> validate_activity_type()
    |> validate_required_property(AS.actor, "no actor")
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

  # TODO: this is duplicated from Actor module. Move to a nice place. Best probably create a Macro for such kind of Schema objects.
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

end
