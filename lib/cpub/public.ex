defmodule CPub.Public do
  @moduledoc """
  Query to access public activities (aka the public timeline).
  """
  import Ecto.Query, only: [from: 2]

  alias CPub.NS.ActivityStreams, as: AS

  @doc """
  Returns all public activities.
  """
  def get_public do
    public_collection = RDF.IRI.new(AS.Public)

    public_query =
      from a in CPub.Activity,
        where: ^public_collection in a.recipients

    public_query
    |> CPub.Repo.all()
    |> CPub.Repo.preload(:object)
  end
end
