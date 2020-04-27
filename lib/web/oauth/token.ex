defmodule CPub.Web.OAuth.Token do
  @moduledoc """
  Schema for OAuth token.
  """

  use Ecto.Schema

  alias CPub.User
  alias CPub.Web.OAuth.App

  @type t :: %__MODULE__{
          token: String.t() | nil,
          refresh_token: String.t() | nil,
          scopes: [String.t()] | nil,
          valid_until: NaiveDateTime.t() | nil,
          user_id: RDF.IRI.t() | nil,
          app_id: integer | nil
        }

  schema "oauth_tokens" do
    field(:token, :string)
    field(:refresh_token, :string)
    field(:scopes, {:array, :string}, default: [])
    field(:valid_until, :naive_datetime_usec)

    belongs_to(:user, User)
    belongs_to(:app, App)

    timestamps()
  end
end
