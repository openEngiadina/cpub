defmodule CPub.User do
  alias CPub.DB
  alias CPub.ERIS

  # RDF namespaces
  alias CPub.NS.ActivityStreams, as: AS

  alias RDF.FragmentGraph

  alias Memento.{Transaction, Query}

  use Memento.Table,
    attributes: [:id, :username, :profile],
    index: [:username],
    type: :set

  defp default_profile(username) do
    FragmentGraph.new()
    |> FragmentGraph.add(RDF.type(), AS.Person)
    |> FragmentGraph.add(AS.preferredUsername(), username)
  end

  def create(username) do
    DB.transaction(fn ->
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
          DB.abort(:user_already_exists)
      end
    end)
  end

  defp load_profile(%__MODULE__{} = user) do
    with {:ok, profile} <- ERIS.get_rdf(user.profile) |> IO.inspect() do
      %{user | profile: profile}
    else
      error ->
        DB.abort(error)
    end
  end

  defp load_profile([user]), do: load_profile(user)
  defp load_profile(nil), do: DB.abort(:not_found)
  defp load_profile([]), do: DB.abort(:not_found)

  @doc """
  Get a single user by username.
  """
  def get(username) do
    DB.transaction(fn ->
      Query.select(__MODULE__, {:==, :username, username})
      |> IO.inspect()
      |> load_profile
    end)
  end

  @doc """
  Get a single user by id.
  """
  def get_by_id(id) do
    DB.transaction(fn ->
      Query.read(__MODULE__, id)
      |> load_profile
    end)
  end

  @doc """
  Get the user profile
  """
  def get_profile(%__MODULE__{} = user) do
    user.profile
  end
end
