# SPDX-FileCopyrightText: 2020-2021 pukkamustard <pukkamustard@posteo.net>
# SPDX-FileCopyrightText: 2020-2021 rustra <rustra@disroot.org>
#
# SPDX-License-Identifier: AGPL-3.0-or-later

defmodule CPub.Web.Authorization do
  @moduledoc """
  An OAuth 2.0 Authorization.

  An `CPub.Web.Authorization.Authorization` includes a code that can be used to
  obtain a `CPub.Web.Authorization.Token`. The token can be used to access
  resources. The Authorization can only be used once and is valid for only 10
  minutes after creation.

  The `CPub.Web.Authorization.Authorization` remains in the database and can be
  reused to refresh a token (see https://tools.ietf.org/html/rfc6749#section-6)
  until it is explicitly revoked (deleted). On deletion all
  `CPub.Web.Authorization.Token`s that were created based on the Authorization
  are revoked (deleted).

  Protected routes have a authorization assigned (see
  `CPub.Web.Authorization.AuthorizationPlug`).
  """

  alias CPub.DB
  alias CPub.User
  alias CPub.Web.Authorization.Client
  alias CPub.Web.Authorization.Scope

  use Memento.Table,
    attributes: [
      :id,
      :user,
      :client,
      :scope,
      :authorization_code,
      :refresh_token,
      :code_used,
      :created_at
    ],
    index: [:authorization_code, :refresh_token],
    type: :set

  @type t :: %__MODULE__{
          id: String.t(),
          user: String.t(),
          client: String.t(),
          scope: [atom],
          authorization_code: String.t(),
          refresh_token: String.t(),
          code_used: bool,
          created_at: NaiveDateTime.t()
        }

  @doc """
  Create a new `Authorization` for the given `user`, `client` and `scope`.
  """
  @spec create(User.t(), Client.t(), [String.t() | atom]) :: {:ok, t} | {:error, any}
  def create(%User{} = user, %Client{} = client, scope) do
    DB.transaction(fn ->
      with {:ok, scope} <- Scope.parse(scope),
           true <- Scope.scope_subset?(scope, client.scope) do
        %__MODULE__{
          id: UUID.uuid4(),
          user: user.id,
          client: client.id,
          scope: scope,
          authorization_code: random_code(),
          refresh_token: random_code(),
          code_used: false,
          created_at: NaiveDateTime.utc_now()
        }
        |> Memento.Query.write()
      else
        _ ->
          DB.abort(:invalid_scope)
      end
    end)
  end

  @doc """
  Create a new `Authorization` for the given `user` and scope without
  associating a client.
  """
  @spec create(User.t(), [String.t()]) :: {:ok, t} | {:error, any}
  def create(%User{} = user, scope) do
    DB.transaction(fn ->
      case Scope.parse(scope) do
        {:ok, scope} ->
          %__MODULE__{
            id: UUID.uuid4(),
            user: user.id,
            scope: scope,
            authorization_code: random_code(),
            refresh_token: random_code(),
            code_used: false,
            created_at: NaiveDateTime.utc_now()
          }
          |> Memento.Query.write()

        _ ->
          DB.abort(:invalid_scope)
      end
    end)
  end

  @doc """
  Get an authorization by id.
  """
  @spec get(String.t()) :: {:ok, t} | {:error, any}
  def get(id) do
    DB.transaction(fn ->
      Memento.Query.read(__MODULE__, id)
    end)
  end

  @doc """
  Get an authorization by the code.
  """
  @spec get_by_code(String.t()) :: {:ok, t} | {:error, any}
  def get_by_code(code) do
    DB.transaction(fn ->
      case Memento.Query.select(__MODULE__, {:==, :authorization_code, code}) do
        [authorization] ->
          authorization

        _ ->
          DB.abort(:not_found)
      end
    end)
  end

  @doc """
  Get an authorization by the refresh token.
  """
  @spec get_by_refresh_token(String.t()) :: {:ok, t} | {:error, any}
  def get_by_refresh_token(token) do
    DB.transaction(fn ->
      case Memento.Query.select(__MODULE__, {:==, :refresh_token, token}) do
        [authorization] ->
          authorization

        _ ->
          DB.abort(:not_found)
      end
    end)
  end

  @doc """
  Mark the authorization code as used.
  """
  @spec use_code!(t) :: {:ok, t} | {:error, any}
  def use_code!(%__MODULE__{} = authorization) do
    DB.transaction(fn ->
      Memento.Query.delete_record(authorization)
      Memento.Query.write(%{authorization | code_used: true})
    end)
  end

  @doc """
  Returns the number of seconds the Authorization code is valid for after
  initial creation.
  """
  # one hour
  @spec valid_for :: non_neg_integer
  def valid_for, do: 3_600

  @doc """
  Returns true if the `Authorization` has expired (has been created more than 10 minutes ago).
  """
  @spec expired?(t) :: bool
  def expired?(%__MODULE__{} = authentication) do
    valid_for() <= NaiveDateTime.diff(NaiveDateTime.utc_now(), authentication.created_at)
  end

  # generate a random code/token
  @spec random_code :: String.t()
  defp random_code do
    :crypto.strong_rand_bytes(32)
    |> Base.encode32(padding: false)
  end
end
