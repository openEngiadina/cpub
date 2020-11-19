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
  alias CPub.Web.Authorization

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

  # generate a random code/token
  defp random_code do
    :crypto.strong_rand_bytes(32)
    |> Base.encode32(padding: false)
  end

  @doc """
  Create a new `Authorization` for the given `user`, `client` and `scope`.
  """
  def create(%User{} = user, %Authorization.Client{} = client, scope) do
    DB.transaction(fn ->
      with {:ok, scope} <- Authorization.Scope.parse(scope),
           true <- Authorization.Scope.scope_subset?(scope, client.scope) do
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
  Create a new `Authorization` for the given `user` and scope without associating a client.
  """
  def create(%User{} = user, scope) do
    DB.transaction(fn ->
      case Authorization.Scope.parse(scope) do
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
  def get(id) do
    DB.transaction(fn ->
      Memento.Query.read(__MODULE__, id)
    end)
  end

  @doc """
  Get an authorization by the code.
  """
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
  def use_code!(%__MODULE__{} = authorization) do
    DB.transaction(fn ->
      Memento.Query.delete_record(authorization)
      Memento.Query.write(%{authorization | code_used: true})
    end)
  end

  @doc """
  Returns the number of seconds the Authorization code is valid for after initial creation.
  """
  # one hour
  def valid_for, do: 3600

  @doc """
  Returns true if the `Authorization` has expired (has been created more than 10 minutes ago).
  """
  def expired?(%__MODULE__{} = authentication) do
    valid_for() <= NaiveDateTime.diff(NaiveDateTime.utc_now(), authentication.created_at)
  end
end
