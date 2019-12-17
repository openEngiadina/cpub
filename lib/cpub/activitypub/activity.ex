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

  alias SPARQL.Query.Result

  alias CPub.Repo
  alias CPub.NS.ActivityStreams

  @primary_key {:id, CPub.ID, autogenerate: true}
  @foreign_key_type :binary_id
  schema "objects" do
    field :data, RDF.Description.EctoType
    timestamps()
  end

  @doc false
  def changeset(activity \\ %Activity{}, attrs) do
    activity
    |> cast(attrs, [:id, :data])
    |> CPub.ID.validate()
    |> validate_required([:id, :data])
    |> unique_constraint(:id, name: "objects_pkey")
    |> validate_activity_type()
  end

  def is_activity?(description) do
    description[RDF.type]
    |> Enum.any?(&(&1 in ActivityPub.activity_types))
  end

  defp validate_activity_type(changeset) do

    activity = get_field(changeset, :data)

    if activity[RDF.type] |> Enum.any?(&(&1 in ActivityPub.activity_types)) do
      changeset
    else
      changeset
      |> add_error(:data, "not an ActivityPub activity")
    end

  end

end
