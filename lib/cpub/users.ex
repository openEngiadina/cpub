defmodule CPub.Users do

  alias Ecto.Multi

  alias CPub.Users.User
  alias CPub.ActivityPub
  alias CPub.Repo
  alias CPub.WebACL.Authorization

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
    |> Multi.insert(:authorizations_full, &(create_authorizations(
              "full",
              %{mode_read: true,
                mode_write: true,
                mode_append: true,
                mode_control: true
              },&1)))
    |> Multi.insert(:authorizations_read_only, &(create_authorizations(
              "read_only",
              %{mode_read: true,
                mode_write: false,
                mode_append: false,
                mode_control: false
              },&1)))
    |> Repo.transaction
  end

  defp create_authorizations(name, attrs, %{user: user}) do
    %Authorization{
      id: user.id |> CPub.ID.extend("authorizations/" <> name),
      user_id: user.id}
    |> Authorization.changeset(attrs)
  end

  def list_users do
    Repo.all(User)
    |> Repo.preload([:actor, :authorizations])
  end

  def verify_user(username, password) do
    Repo.get_by(User, username: username)
    |> Repo.preload([:actor])
    |> Pbkdf2.check_pass(password, hash_key: :password)
  end

end
