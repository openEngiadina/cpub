# SPDX-FileCopyrightText: 2020-2021 pukkamustard <pukkamustard@posteo.net>
# SPDX-FileCopyrightText: 2020-2021 rustra <rustra@disroot.org>
#
# SPDX-License-Identifier: AGPL-3.0-or-later

defmodule CPub.User do
  @moduledoc """
  A CPub user.
  """

  use Memento.Table,
    attributes: [:id, :username, :profile, :inbox, :outbox, :followers, :following],
    index: [:username],
    type: :set

  alias Memento.Query

  alias RDF.FragmentGraph
  alias RDF.IRI

  alias CPub.DB
  alias CPub.ERIS
  alias CPub.NS.ActivityStreams, as: AS

  @type t :: %__MODULE__{
          id: String.t(),
          username: String.t(),
          profile: FragmentGraph.t(),
          inbox: IRI.t(),
          outbox: IRI.t(),
          followers: IRI.t(),
          following: IRI.t()
        }

  # don't check if user already exists, just write.
  @spec create!(String.t()) :: t
  def create!(username) do
    with {:ok, profile_read_capability} <- default_profile(username) |> ERIS.put(),
         inbox <- DB.Set.new(),
         outbox <- DB.Set.new(),
         followers <- DB.Set.new(),
         following <- DB.Set.new() do
      %__MODULE__{
        id: UUID.uuid4(),
        username: username,
        profile: profile_read_capability,
        inbox: inbox,
        outbox: outbox,
        followers: followers,
        following: following
      }
      |> Query.write()
    else
      {:error, reason} ->
        DB.abort(reason)

      _ ->
        DB.abort(:could_not_create_user)
    end
  end

  @spec create(String.t()) :: {:ok, t} | {:error, any}
  def create(username) do
    DB.transaction(fn ->
      case Query.select(__MODULE__, {:==, :username, username}) do
        [] ->
          create!(username)

        _ ->
          DB.abort(:user_already_exists)
      end
    end)
  end

  @spec default_profile(String.t()) :: FragmentGraph.t()
  defp default_profile(username) do
    now =
      NaiveDateTime.utc_now()
      |> NaiveDateTime.truncate(:second)
      |> NaiveDateTime.to_iso8601()
      |> RDF.XSD.dateTime()

    FragmentGraph.new()
    |> FragmentGraph.add(RDF.type(), AS.Person)
    |> FragmentGraph.add(AS.preferredUsername(), username)
    |> FragmentGraph.add(AS.published(), now)
  end

  @spec load_profile(any) :: t
  defp load_profile(%__MODULE__{} = user) do
    case ERIS.get_rdf(user.profile) do
      {:ok, profile} -> %{user | profile: profile}
      error -> DB.abort(error)
    end
  end

  defp load_profile([user]), do: load_profile(user)
  defp load_profile(nil), do: DB.abort(:not_found)
  defp load_profile([]), do: DB.abort(:not_found)

  @doc """
  Get a single user by username.
  """
  @spec get(String.t()) :: {:ok, t} | {:error, any}
  def get(username) do
    DB.transaction(fn ->
      Query.select(__MODULE__, {:==, :username, username})
      |> load_profile
    end)
  end

  @doc """
  Get a single user by id.
  """
  @spec get_by_id(String.t()) :: {:ok, t} | {:error, any}
  def get_by_id(id) do
    DB.transaction(fn ->
      Query.read(__MODULE__, id)
      |> load_profile
    end)
  end

  @doc """
  Get the user profile
  """
  @spec get_profile(t) :: FragmentGraph.t()
  def get_profile(%__MODULE__{} = user) do
    user.profile
  end
end
