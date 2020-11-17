defmodule CPub.User.Registration do
  @moduledoc """
  `CPub.User.Registration` models how a `CPub.User` is registered and can
  authenticate with CPub.

  Currently there are three types of registrations:

  - `:internal`: A password that is stored in the CPub database.
  - `:oidc`: An external OpenID Connect identity provider
  - `:mastodon`: A server that implements the Mastodon OAuth protocol
  """

  use Memento.Table,
    attributes: [
      :id,
      :user,
      :type,
      # for internal registration
      :password,
      # for oidc and mastodon registration
      :site,
      :external_id
    ],
    type: :set

  @doc """
  Create an internal registration with a password.
  """
  def create_internal(user, password) do
    %__MODULE__{
      id: UUID.uuid4(),
      user: user.id,
      type: :internal,
      password: Argon2.add_hash(password)
    }
  end
end
