defmodule CPub.LDP.RDFSource do
  use Ecto.Schema
  import Ecto.Changeset

  alias CPub.LDP.RDFSource

  @behaviour Access

  @primary_key {:id, CPub.ID, autogenerate: true}
  @foreign_key_type :binary_id
  schema "ldp_rs" do

    # data field holds an RDF graph
    field :data, RDF.Graph.EctoType

    many_to_many :authorizations, CPub.WebACL.Authorization,
      join_through: "authorizations_resources",
      join_keys: [resource_id: :id, authorization_id: :id]

    timestamps()
  end

  @doc """
  Returns a new RDFSource.
  """
  def new(opts \\ []) do
    id =  Keyword.get(opts, :id, CPub.ID.generate())
    data = Keyword.get(opts, :data, RDF.Graph.new())
    %RDFSource{id: id, data: data}
  end

  @doc false
  def changeset(rdf_source \\ new()) do
    rdf_source
    |> change()
    # NOTE We force a change instead of using Ecto.Changeset.cast to figure out which fields have changed. This is ok as :data is the only field in the schema and it does not make sense to optimize by restricting changeset to field that change.
    |> force_change(:data, rdf_source.data)
    |> CPub.ID.validate
    |> validate_required([:id, :data])
    |> unique_constraint(:id, name: "ldp_rs_pkey")
  end

  @doc """
  See `RDF.Graph.fetch`.
  """
  @impl Access
  def fetch(%RDFSource{data: data}, key) do
    Access.fetch(data, key)
  end

  @doc """
  See `RDF.Graph.get_and_update`
  """
  @impl Access
  def get_and_update(%RDFSource{} = object, key, fun) do
    with {get_value, new_graph} <- Access.get_and_update(object.data, key, fun) do
      {get_value, %{object | data: new_graph}}
    end
  end

  @doc """
  See `RDF.Graph.pop`.
  """
  @impl Access
  def pop(%RDFSource{} = object, key) do
    case Access.pop(object.data, key) do
      {nil, _} ->
        {nil, object}

      {value, new_graph} ->
        {value, %{object | data: new_graph}}
    end
  end

end
