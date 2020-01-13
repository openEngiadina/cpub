defmodule CPub.Users do

  alias Ecto.Multi

  alias CPub.NS.ActivityStreams, as: AS
  alias CPub.NS.LDP

  alias CPub.Repo
  alias CPub.ID

  alias CPub.Users.User
  alias CPub.Users.Authorization

  alias CPub.ActivityPub.Actor
  alias CPub.LDP.BasicContainer

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

    # grant read authorization to inbox and outbox
    |> grant_authorization("authorize read/write on inbox", :inbox, read: true, write: true)
    |> grant_authorization("authorize read/write on outbox", :outbox, read: true, write: true)

    # grant read/write access to actor profile
    |> grant_authorization("authorize read/write on actor", :actor, read: true, write: true)

    |> Repo.transaction
  end

  defp grant_authorization(multi, name, ressource_key, opts) do
    multi
    |> Multi.insert(name, fn %{:user => user, ^ressource_key => ressource} ->
      Authorization.new(user.id, ressource.id, opts)
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
