defmodule CPub.WebACL.AuthorizationResource do
  use Ecto.Schema
  import Ecto.Changeset

  alias CPub.WebACL.Authorization
  alias CPub.LDP.RDFSource
  alias CPub.WebACL.AuthorizationResource

  schema "authorizations_resources" do
    belongs_to :authorization, Authorization, type: CPub.ID
    belongs_to :resource, RDFSource, type: CPub.ID
  end

  @doc """
  Create a new Authorization-Resource mapping and return the changeset to add it.
  """
  def new(%Authorization{} = authorization, %RDFSource{} = resource) do
    %AuthorizationResource{}
    |> change()
    |> put_assoc(:authorization, authorization)
    |> put_assoc(:resource, resource)
    |> validate_required([:resource, :authorization])
    |> assoc_constraint(:authorization)
    |> assoc_constraint(:resource)
    |> unique_constraint(:authorization,
      message: "authorization already associated with ressource",
      name: "authorizations_resources_authorization_id_resource_id_index")
  end

  def new(%RDF.IRI{} = authorization, %RDF.IRI{} = resource) do
    %AuthorizationResource{authorization_id: authorization, resource_id: resource}
    |> change()
    |> assoc_constraint(:authorization)
    |> assoc_constraint(:resource)
    |> unique_constraint(:authorization,
        message: "authorization already associated with ressource",
        name: "authorizations_resources_authorization_id_resource_id_index")
  end

end
