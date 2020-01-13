defmodule CPub.ActivityPub.Request do
  @moduledoc """
  Helpers to define a pipeline for handling an activity.

  Inspired by Plug.
  """

  alias Ecto.Multi

  alias CPub.Repo

  alias CPub.Users.User
  alias CPub.Users.Authorization

  alias CPub.ActivityPub.Request

  defstruct [:multi,
              :id,
              :object_id,
              :activity,
              :data,
              :user,
              recipients: []
            ]

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
    %{request | multi: request.multi |> Multi.error(name, error)}
  end

  @doc """
  Grant authorization access to a resource
  """
  def authorize(request, %RDF.IRI{} = user_id, %RDF.IRI{} = resource_id, opts) do
    # TODO: ensure name is unique by including read/write fields
    name = "grant " <> to_string(user_id) <> " access to " <> to_string(resource_id)
    request
    |> insert(name, Authorization.new(user_id, resource_id, opts))
  end

  def authorize(request, %User{} = user, %RDF.IRI{} = resource_id, opts) do
    authorize(request, user.id, resource_id, opts)
  end

  def authorize(request, users, %RDF.IRI{} = resource_id, opts) do
    users
    |> List.foldl(request, fn user_id, request ->
      request
      |> authorize(user_id, resource_id, opts)
    end)
  end

  def authorize(request, user, resources, opts) do
    resources
    |> List.foldl(request, fn resource_id, request ->
      request
      |> authorize(user, resource_id, opts)
    end)
  end

  def commit(%Request{} = request) do
    request.multi
    |> Repo.transaction
  end

end
