defmodule CPub.Users do

  alias Ecto.Multi

  alias CPub.NS.ActivityStreams, as: AS
  alias CPub.NS.LDP
  alias CPub.NS.ACL

  alias CPub.Repo
  alias CPub.ID
  alias CPub.Users.User
  alias CPub.ActivityPub.Actor
  alias CPub.LDP.BasicContainer
  alias CPub.WebACL.Authorization
  alias CPub.WebACL.AuthorizationResource

  def create_user(opts \\ []) do
    username = Keyword.get(opts, :username)
    password = Keyword.get(opts, :password)

    # set the ID to "/users/<username>"
    id = "users/" <> username
    |> ID.merge_with_base_url()

    # start a new transaction
    Multi.new

    # create the inbox
    |> Multi.insert(:inbox,
      BasicContainer.new(id: id |> ID.extend("inbox"))
      |> BasicContainer.changeset())

    # create the outbox
    |> Multi.insert(:outbox,
      BasicContainer.new(id: id |> ID.extend("outbox"))
      |> BasicContainer.changeset())

    # create the actor
    |> Multi.insert(:actor, fn %{inbox: inbox, outbox: outbox} ->
      RDF.Description.new(id)
      |> RDF.Description.add(RDF.type, AS.Person)
      |> RDF.Description.add(LDP.inbox, inbox.id)
      |> RDF.Description.add(AS.outbox, outbox.id)
      # Use ACL.default to specify the Authorization that has access to newly created objects
      |> RDF.Description.add(ACL.default, id |> ID.extend("authorizations/full"))
      |> Actor.new()
      |> Actor.changeset()
    end)

    # create the user
    |> Multi.insert(:user, fn %{actor: actor} ->
      %User{}
      |> User.changeset(%{
            id: actor.id,
            username: username,
            password: password,
            actor_id: actor.id})
    end)

    # create default authorizations for user
    |> insert_authorization("authorizations/read", %{mode_read: true})
    |> insert_authorization("authorizations/write", %{mode_write: true})
    |> insert_authorization("authorizations/full", %{mode_read: true,
                                                    mode_write: true,
                                                    mode_append: true,
                                                    mode_control: true})

    # grant read authorization to inbox and outbox
    |> grant_authorization("authorizations/read", to: :inbox)
    |> grant_authorization("authorizations/read", to: :outbox)

    # grant read/write access to actor profile
    |> grant_authorization("authorizations/full", to: :actor)

    |> Repo.transaction
  end

  defp grant_authorization(multi, auth_key, [to: ressource_key]) do
    name = "grant " <> to_string(auth_key) <> " to " <> to_string(ressource_key)
    multi
    |> Multi.insert(name, fn %{^auth_key => authorization, ^ressource_key => ressource} ->
      AuthorizationResource.new(authorization.id, ressource.id)
    end)
  end

  defp insert_authorization(multi, name, attrs) do
    multi
    |> Multi.insert(name, fn %{user: user} ->
      %Authorization{
        id: user.id |> CPub.ID.extend(name),
        user_id: user.id}
      |> Authorization.changeset(attrs)
    end)
  end

  def list_users do
    Repo.all(User)
    |> Repo.preload([:actor])
  end

  def verify_user(username, password) do
    Repo.get_by(User, username: username)
    |> Repo.preload([:actor])
    |> Pbkdf2.check_pass(password, hash_key: :password)
  end

  def get_user(username) do
    Repo.get_by(User, username: username)
    |> Repo.preload([:actor])
  end

end
