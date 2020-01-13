defmodule CPub.Users.Authorization do
  use Ecto.Schema
  import Ecto.Changeset

  alias CPub.Users.User
  alias CPub.LDP.RDFSource

  alias CPub.Users.Authorization

  schema "authorizations" do
    belongs_to :user, User, type: CPub.ID
    belongs_to :resource, RDFSource, type: CPub.ID

    field :read, :boolean, default: false
    field :write, :boolean, default: false
  end

  def new(%RDF.IRI{} = user_id, %RDF.IRI{} = resource_id, opts) do
    %Authorization{
      user_id: user_id,
      resource_id: resource_id,
      read: Keyword.get(opts, :read, false),
      write: Keyword.get(opts, :write, false)
    }
    |> change()
    |> assoc_constraint(:user)
    |> assoc_constraint(:resource)
    |> unique_constraint(:user,
      message: "authorization already exists",
      name: "authorizations_user_id_resource_id_read_write_index")
  end

end
