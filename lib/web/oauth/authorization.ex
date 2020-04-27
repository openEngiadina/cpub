defmodule CPub.Web.OAuth.Authorization do
  @moduledoc """
  Schema for OAuth authorization.
  """

  use Ecto.Schema

  alias CPub.User
  alias CPub.Web.OAuth.App

  @type t :: %__MODULE__{
          token: String.t() | nil,
          scopes: [String.t()] | nil,
          valid_until: NaiveDateTime.t() | nil,
          used: boolean | nil,
          user_id: RDF.IRI.t() | nil,
          app_id: integer | nil
        }

  schema "oauth_authorizations" do
    field(:token, :string)
    field(:scopes, {:array, :string}, default: [])
    field(:valid_until, :naive_datetime_usec)
    field(:used, :boolean, default: false)

    belongs_to(:user, User)
    belongs_to(:app, App)

    timestamps()
  end
end
