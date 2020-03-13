defmodule CPub.Public do
  @moduledoc """
  Query to access public activities (aka the public timeline).
  """
  import Ecto.Query, only: [from: 2]

  alias CPub.{Activity, Repo}
  alias CPub.NS.ActivityStreams, as: AS

  @doc """
  Returns all public activities.
  """
  @spec get_public :: [Activity.t()]
  def get_public do
    public_collection = RDF.iri(AS.Public)

    public_query = from a in Activity, where: ^public_collection in a.recipients

    public_query
    |> Repo.all()
    |> Repo.preload(:object)
  end
end
