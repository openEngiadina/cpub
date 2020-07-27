defmodule CPub.ActivityPub.Request do
  @moduledoc """
  A `Plug` like pipeliner for handling ActivityPub requests.
  """

  alias CPub.{Repo, User}

  alias Ecto.Multi

  @type t :: %__MODULE__{
          multi: Multi.t() | nil,
          graph: RDF.Graph.t() | nil,
          user: User.t() | nil,
          assigns: map()
        }

  @type operation ::
          Ecto.Changeset.t()
          | Ecto.Schema.t()
          | (Ecto.Changeset.t() | Ecto.Schema.t() -> Ecto.Schema.t())

  @type commit_result ::
          {:ok, any}
          | {:error, any}
          | {:error, Ecto.Multi.name(), any, %{required(Ecto.Multi.name()) => any}}

  defstruct [:multi, :graph, :user, :assigns]

  @doc """
  Create a new request pipeline.
  """
  @spec new(RDF.Graph.t(), User.t()) :: t
  def new(%RDF.Graph{} = graph, %User{} = user) do
    %__MODULE__{multi: Multi.new(), graph: graph, user: user, assigns: %{}}
  end

  @doc """
  Helper to run Multi.insert on a request
  """
  @spec insert(t, any, operation, keyword) :: t
  def insert(request, name, operation, opts \\ []) do
    %{request | multi: Multi.insert(request.multi, name, operation, opts)}
  end

  @doc """
  Helper to run Multi.update on a request
  """
  @spec update(t, any, operation, keyword) :: t
  def update(request, name, operation, opts \\ []) do
    %{request | multi: Multi.update(request.multi, name, operation, opts)}
  end

  @doc """
  Cause the request to fail with error.
  """
  @spec error(t, any, any) :: t
  def error(request, name, error) do
    %{request | multi: Multi.error(request.multi, name, error)}
  end

  @doc """
  Commit the result
  """
  @spec commit(t) :: commit_result
  def commit(%__MODULE__{} = request) do
    Repo.transaction(request.multi)
  end

  @doc """
  Assign a temporary value.
  """
  @spec assign(t, any, any) :: t
  def assign(request, key, value) do
    %{request | assigns: request.assigns |> Map.put(key, value)}
  end
end
