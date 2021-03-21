# SPDX-FileCopyrightText: 2020-2021 pukkamustard <pukkamustard@posteo.net>
# SPDX-FileCopyrightText: 2020-2021 rustra <rustra@disroot.org>
#
# SPDX-License-Identifier: AGPL-3.0-or-later

defmodule CPub.Web.Authorization.Token do
  @moduledoc """
  An OAuth 2.0 Token that can be used to access ressources.
  """

  use Memento.Table,
    attributes: [:id, :access_token, :authorization, :created_at],
    index: [:access_token, :authorization],
    type: :set

  alias CPub.DB

  alias CPub.Web.Authorization

  @type t :: %__MODULE__{
          id: String.t(),
          access_token: String.t(),
          authorization: String.t(),
          created_at: NaiveDateTime.t()
        }

  @doc """
  Creates a new (initial) token for an `Authorization`.
  """
  @spec create(Authorization.t()) :: {:ok, t} | {:error, any}
  def create(%Authorization{} = authorization) do
    if authorization.code_used or Authorization.expired?(authorization) do
      {:error, :invalid_grant, "access code expired or already used"}
    else
      DB.transaction(fn ->
        # mark the authorization code as used
        _ = Authorization.use_code!(authorization)

        # create a new token
        %__MODULE__{
          id: UUID.uuid4(),
          access_token: random_token(),
          authorization: authorization.id,
          created_at: NaiveDateTime.utc_now()
        }
        |> Memento.Query.write()
      end)
    end
  end

  @doc """
  Creates a refreshed token for an `Authorization`.
  """
  @spec refresh(Authorization.t()) :: {:ok, t} | {:error, any}
  def refresh(%Authorization{} = authorization) do
    DB.transaction(fn ->
      %__MODULE__{
        id: UUID.uuid4(),
        access_token: random_token(),
        authorization: authorization.id,
        created_at: NaiveDateTime.utc_now()
      }
      |> Memento.Query.write()
    end)
  end

  @doc """
  Get token by access token.
  """
  @spec get(String.t()) :: {:ok, t} | {:error, any}
  def get(access_token) do
    DB.transaction(fn ->
      case Memento.Query.select(__MODULE__, {:==, :access_token, access_token}) do
        [token] ->
          token

        _ ->
          DB.abort(:not_found)
      end
    end)
  end

  @doc """
  Returns the numer of seconds the Token is valid for after creation.
  """
  # 60 days
  @spec valid_for :: non_neg_integer
  def valid_for, do: 60 * 60 * 24 * 60

  @doc """
  Returns true if the Token is expired and can no longer be used to access a ressource.
  """
  @spec expired?(t) :: bool
  def expired?(%__MODULE__{} = token) do
    valid_for() <= NaiveDateTime.diff(NaiveDateTime.utc_now(), token.created_at)
  end

  # generate a new random token
  @spec random_token :: String.t()
  defp random_token do
    :crypto.strong_rand_bytes(32)
    |> Base.encode32(padding: false)
  end
end
