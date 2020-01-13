defmodule CPub.ActivityPub.Request do
  @moduledoc """
  Helpers to define a pipeline for handling an activity.

  Inspired by Plug.
  """

  alias Ecto.Multi

  alias CPub.Repo
  alias CPub.Users.User

  alias CPub.WebACL.AuthorizationResource

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
  def authorize(request, %RDF.IRI{} = authorizaton_id, %RDF.IRI{} = resource_id) do
    name = "grant " <> to_string(authorizaton_id) <> " to " <> to_string(resource_id)
    request
    |> insert(name, AuthorizationResource.new(authorizaton_id, resource_id))
  end

  def authorize(request, authorizations, %RDF.IRI{} = resource_id) do
    authorizations
    |> List.foldl(request, fn authorizaton_id, request ->
      request
      |> authorize(authorizaton_id, resource_id)
    end)
  end

  def commit(%Request{} = request) do
    request.multi
    |> Repo.transaction
  end

end
