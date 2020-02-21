defmodule CPub.Public do
  import Ecto.Query, only: [from: 2]

  alias CPub.NS.ActivityStreams, as: AS

  @doc """
  Returns all public activities.
  """
  def get_public() do
    public_collection = AS.Public |> RDF.IRI.new()
    CPub.Repo.all(from a in CPub.Activity, where: ^public_collection in a.recipients)
    |> CPub.Repo.preload(:object)
  end
end
