defmodule CPub.Users do

  alias Ecto.Multi

  alias CPub.Users.User
  alias CPub.ActivityPub
  alias CPub.Repo
  alias CPub.WebACL.Authorization
  alias CPub.WebACL.AuthorizationResource

  def create_user(opts \\ []) do
    username = Keyword.get(opts, :username)
    password = Keyword.get(opts, :password)
    opts = Keyword.put_new(opts, :id, CPub.ID.merge_with_base_url("users/" <> username))
    ActivityPub.create_actor_multi(opts)
    |> Multi.insert(:user, fn %{actor: actor} ->
      %User{}
      |> User.changeset(%{
            id: actor.id,
            username: username,
            password: password,
            actor_id: actor.id})
    end)
    |> insert_authorization("authorizations/read", %{mode_read: true})
    |> insert_authorization("authorizations/write", %{mode_write: true})
    |> grant_authorization("authorizations/read", to: :inbox)
    |> grant_authorization("authorizations/read", to: :outbox)
    |> grant_authorization("authorizations/read", to: :actor)
    |> grant_authorization("authorizations/write", to: :actor)
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
  end

end
