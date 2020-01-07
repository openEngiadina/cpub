defmodule CPub.WebACL.Authorization do
  use Ecto.Schema
  import Ecto.Changeset

  alias CPub.WebACL.Authorization
  alias CPub.LDP.RDFSource
  alias CPub.Users.User

  @primary_key {:id, CPub.ID, autogenerate: true}
  @foreign_key_type :binary_id
  schema "authorizations" do

    # An authorization always belongs to something that can authenticate, i.e. a user
    # In WebACL lingo this is the agent
    belongs_to :user, User, type: CPub.ID

    # WebACL modes of access (https://github.com/solid/web-access-control-spec#modes-of-access)
    field :mode_read, :boolean, default: false
    field :mode_write, :boolean, default: false
    field :mode_append, :boolean, default: false
    field :mode_control, :boolean, default: false

    many_to_many :resources, CPub.LDP.RDFSource, join_through: "authorizations_ldp_rs"

    timestamps()
  end

  def changeset(%Authorization{} = authorization, attrs \\ %{}) do
    authorization
    |> cast(attrs, [:id, :user_id, :mode_read, :mode_write, :mode_append, :mode_control])
    |> validate_required([:user_id, :mode_read, :mode_write, :mode_append, :mode_control])
    |> assoc_constraint(:user)
  end
end
