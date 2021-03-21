# SPDX-FileCopyrightText: 2020-2021 pukkamustard <pukkamustard@posteo.net>
# SPDX-FileCopyrightText: 2020-2021 rustra <rustra@disroot.org>
#
# SPDX-License-Identifier: AGPL-3.0-or-later

defmodule CPub.User.Registration do
  @moduledoc """
  `CPub.User.Registration` models how a `CPub.User` is registered and can
  authenticate with CPub.

  Currently there are three types of registration providers:

  - `:internal`: A password that is stored in the CPub database.
  - `:oidc`: An external OpenID Connect identity provider
  - `:mastodon`: A server that implements the Mastodon OAuth protocol
  """

  use Memento.Table,
    attributes: [
      :id,
      :user,
      :provider,
      # for internal registration
      :password,
      # for oidc and mastodon registration
      :site,
      :external_id
    ],
    index: [:user, :site],
    type: :set

  alias CPub.DB
  alias CPub.User

  @type t :: %__MODULE__{
          id: String.t(),
          user: String.t(),
          provider: atom | String.t(),
          password: String.t(),
          site: String.t(),
          external_id: String.t()
        }

  @doc """
  Create an internal registration with a password.
  """
  @spec create_internal(User.t(), String.t()) :: {:ok, t} | {:error, any}
  def create_internal(user, password) do
    DB.transaction(fn ->
      %__MODULE__{
        id: UUID.uuid4(),
        user: user.id,
        provider: :internal,
        password: Argon2.add_hash(password)
      }
      |> Memento.Query.write()
    end)
  end

  @doc """
  Create an internal registration with a password.
  """
  @spec create_external(User.t(), atom | String.t(), String.t(), String.t()) ::
          {:ok, t} | {:error, any}
  def create_external(user, provider, site, external_id) do
    DB.transaction(fn ->
      %__MODULE__{
        id: UUID.uuid4(),
        user: user.id,
        provider: provider,
        site: site,
        external_id: external_id
      }
      |> Memento.Query.write()
    end)
  end

  @doc """
  Check if password matches registered password.
  """
  @spec check_internal(t, String.t()) :: :ok | :invalid_password
  def check_internal(%__MODULE__{provider: :internal} = registration, password) do
    case Argon2.check_pass(registration.password, password) do
      {:ok, _} ->
        :ok

      {:error, _} ->
        :invalid_password
    end
  end

  @doc """
  Get the registration for a user.
  """
  @spec get_user_registration(User.t()) :: {:ok, t} | {:error, any}
  def get_user_registration(user) do
    DB.transaction(fn ->
      case Memento.Query.select(__MODULE__, {:==, :user, user.id}) do
        [registration | _] ->
          registration

        [] ->
          DB.abort(:not_found)
      end
    end)
  end

  @spec get_external(String.t(), atom | String.t(), String.t()) :: {:ok, t} | {:error, any}
  def get_external(site, provider, external_id) do
    DB.transaction(fn ->
      case Memento.Query.select(__MODULE__, [
             {:==, :site, site},
             {:==, :provider, provider},
             {:==, :external_id, external_id}
           ]) do
        [registration | _] ->
          registration

        [] ->
          DB.abort(:not_found)
      end
    end)
  end
end
