defmodule CPub.ActivityPub.Request do
  @moduledoc """
  Helpers to define a pipeline for handling an activity.

  Inspired by Plug.
  """

  alias CPub.{Repo, User}

  alias Ecto.Multi

  @type t :: %__MODULE__{
          multi: Multi.t(),
          id: RDF.IRI.t(),
          activity: RDF.Description.t(),
          object_id: RDF.IRI.t(),
          data: RDF.Graph.t(),
          user: User.t()
        }

  @type operation ::
          Ecto.Changeset.t()
          | Ecto.Schema.t()
          | (Ecto.Changeset.t() | Ecto.Schema.t() -> Ecto.Schema.t())

  @type commit_result ::
          {:ok, any}
          | {:error, any}
          | {:error, Ecto.Multi.name(), any, %{required(Ecto.Multi.name()) => any}}

  defstruct [:multi, :id, :object_id, :activity, :data, :user]

  @spec new(RDF.IRI.t(), RDF.Graph.t(), User.t()) :: t
  def new(%RDF.IRI{} = id, %RDF.Graph{} = data, %User{} = user) do
    %__MODULE__{
      multi: Multi.new(),
      id: id,
      activity: data[id],
      object_id: CPub.ID.generate(type: :object),
      data: data,
      user: user
    }
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

  @spec commit(t) :: commit_result
  def commit(%__MODULE__{} = request) do
    Repo.transaction(request.multi)
  end
end
