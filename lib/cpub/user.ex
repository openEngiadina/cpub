defmodule CPub.User do
  alias CPub.Database
  alias CPub.ERIS

  # RDF namespaces
  alias CPub.NS.ActivityStreams, as: AS

  alias RDF.FragmentGraph

  alias Memento.{Transaction, Query}

  use Memento.Table,
    attributes: [:id, :username, :profile, :registration],
    index: [:username],
    type: :set

  defp default_profile(username) do
    FragmentGraph.new()
    |> FragmentGraph.add(RDF.type(), AS.Person)
    |> FragmentGraph.add(AS.preferredUsername(), username)
  end

  def create(username) do
    Database.transaction(fn ->
      case Query.select(__MODULE__, {:==, :username, username}) do
        [] ->
          with {:ok, profile_read_capability} <- default_profile(username) |> ERIS.put() do
            user = %__MODULE__{
              id: UUID.uuid4(),
              username: username,
              profile: profile_read_capability
            }

            Query.write(user)
          else
            error ->
              Transaction.abort(error)
          end

        _ ->
          Database.abort(:user_already_exists)
      end
    end)
  end

  @doc """
  Get a single user by username.
  """
  def get(username) do
    Database.transaction(fn ->
      case Query.select(__MODULE__, {:==, :username, username}) do
        [] ->
          Database.abort(:not_found)

        [user] ->
          with {:ok, profile} <- ERIS.get_rdf(user.profile) |> IO.inspect() do
            %{user | profile: profile}
          else
            error ->
              Database.abort(error)
          end
      end
    end)
  end
end
