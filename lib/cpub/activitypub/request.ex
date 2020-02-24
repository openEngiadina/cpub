defmodule CPub.ActivityPub.Request do
  @moduledoc """
  Helpers to define a pipeline for handling an activity.

  Inspired by Plug.
  """

  alias CPub.ActivityPub.Request
  alias CPub.{Repo, User}

  alias Ecto.Multi

  defstruct [:multi, :id, :object_id, :activity, :data, :user]

  def new(%RDF.IRI{} = id, %RDF.Graph{} = data, %User{} = user) do
    %Request{
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
  def insert(request, name, changeset_or_struct_or_fun, opts \\ []) do
    %{request | multi: Multi.insert(request.multi, name, changeset_or_struct_or_fun, opts)}
  end

  @doc """
  Helper to run Multi.update on a request
  """
  def update(request, name, changeset_or_struct_or_fun, opts \\ []) do
    %{request | multi: Multi.update(request.multi, name, changeset_or_struct_or_fun, opts)}
  end

  @doc """
  Cause the request to fail with error.
  """
  def error(request, name, error) do
    %{request | multi: Multi.error(request.multi, name, error)}
  end

  def commit(%Request{} = request) do
    Repo.transaction(request.multi)
  end
end
