defmodule CPub.ActivityPub do

  import RDF.Sigils
  alias Ecto.Multi

  alias CPub.NS.ActivityStreams
  alias CPub.Objects.Object
  alias CPub.Repo

 # The ActivityStreams ontology
  @activitystreams RDF.Turtle.read_file!("./priv/vocabs/activitystreams2.ttl")

  @query_get_activity SPARQL.query("""
  select ?activity ?activity_type
  where {
    ?activity a ?activity_type .
    ?activity_type rdfs:subClassOf as:Activity .
  }
  """)
  @doc """
  Extract type of Activity and Activity as RDF.Description from any RDF.Data
  """
  def get_activity(data) do
    query_result = data
    |> RDF.Data.merge(@activitystreams)
    |> SPARQL.execute_query(@query_get_activity)
    case query_result do
      %SPARQL.Query.Result{results: [%{"activity" => activity_id,
                                        "activity_type" => activity_type}]} ->
        {:ok, activity_type, activity_id}

      _ ->
        {:error, "Could not extract Activity."}
    end
  end

  @query_get_object SPARQL.query("""
  select ?activity ?object
  where {
  ?activity as:object ?object
  }
  """)
  @doc """
  Get the object id of an activity
  """
  def get_object(data, activity_id) do
    query_result = data
    |> SPARQL.execute_query(@query_get_object)
    case query_result do
      %SPARQL.Query.Result{results: [%{"activity" => activity_id_from_query,
                                        "object" => object}]} when activity_id == activity_id_from_query ->
        {:ok, object}

      _ ->
        {:error, "Could not get object."}
    end
  end

  def handle(data) do
    with {:ok, activity_type, activity} <- get_activity(data) do
      handle(activity_type, activity, data)
    end
  end

  def handle(~I<http://www.w3.org/ns/activitystreams#Create>, activity_id, data) do
    new_object_id = CPub.ID.generate()
    new_activity_id = CPub.ID.generate()
    with {:ok, object_id} <- get_object(data, activity_id),
    # replace the ids with freshly generated ones
    data <- data
    |> replace_subject(object_id, new_object_id)
    |> replace_subject(activity_id, new_activity_id),
    # Extract just the activity
    activity <- data |> RDF.Data.description(new_activity_id),
    # Extract just the object
    object <- data |> RDF.Data.description(new_object_id)
      do

      Multi.new
      |> Multi.insert(:object, Object.changeset(%{data: object, id: new_object_id}))
      |> Multi.insert(:activity, Object.changeset(%{data: activity, id: new_activity_id}))
      |> Repo.transaction()

    end
  end

  def handle(_, _activity, _data) do
    {:error, "Do not know how to handle activity."}
  end

  def replace_subject(data, subject_to_replace, replace_with) do
    data
    |> Enum.reduce(RDF.Graph.new(), fn {s, p, o}, graph ->
      cond do
        s == subject_to_replace ->
          graph |> RDF.Graph.add(replace_with, p, o)

        o == subject_to_replace ->
          graph |> RDF.Graph.add(s, p, replace_with)

        true ->
          graph |> RDF.Graph.add(s, p, o)
      end
    end)
  end

end
