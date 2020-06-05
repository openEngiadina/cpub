defmodule CPub.Repo.Migrations.EditRedirectUrisType do
  use Ecto.Migration

  def up do
    execute("""
    alter table oauth_apps
      alter redirect_uris drop default,
      alter redirect_uris type character varying[] using array[redirect_uris],
      alter redirect_uris set default '{}';
    """)
  end

  def down do
    execute("""
    alter table oauth_apps
      alter redirect_uris drop default,
      alter redirect_uris type character varying(255);
    """)

    execute("""
    update oauth_apps set redirect_uris = replace(redirect_uris, '{', '');
    """)

    execute("""
    update oauth_apps set redirect_uris = replace(redirect_uris, '}', '');
    """)
  end
end
