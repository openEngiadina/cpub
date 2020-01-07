defmodule CPub.Users do

  alias Ecto.Multi

  alias CPub.Users.User
  alias CPub.ActivityPub
  alias CPub.Repo

  def create_user(opts \\ []) do
    username = Keyword.get(opts, :username)
    password = Keyword.get(opts, :password)
    ActivityPub.create_actor_multi(opts)
    |> Multi.insert(:user, fn %{actor: actor} ->
      %User{}
      |> User.changeset(%{username: username, password: password, actor_id: actor.id})
    end)
    |> Repo.transaction
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

end
