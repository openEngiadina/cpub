defmodule CPub.Web.OAuth.OAuthController do
  use CPub.Web, :controller

  alias CPub.{Config, Registration, Repo, User}
  alias CPub.Web.OAuth.{App, Authenticator, Authorization, Scopes, Token, Utils}
  alias CPub.Web.OAuth.Token.Strategy.RefreshToken
  alias CPub.Web.OAuth.Token.Strategy.Revoke, as: RevokeToken

  alias Ueberauth.{Auth, Failure}

  @oob_token_redirect_uri "urn:ietf:wg:oauth:2.0:oob"

  @oauth_default_scopes ["read"]
  @oidc_default_scopes ["openid"]

  action_fallback CPub.Web.OAuth.FallbackController

  plug :fetch_session
  plug :fetch_flash

  #####################################################
  ### OAuth Client (support for external providers) ###
  #####################################################

  if Config.auth_consumer_enabled?(), do: plug(Ueberauth)

  @doc """
  Prepares OAuth request to an OpenID Connect provider for Ueberauth.
  """
  @spec prepare_request(Plug.Conn.t(), map) :: Plug.Conn.t()
  def prepare_request(%Plug.Conn{} = conn, %{"provider" => "oidc_" <> oidc_provider}) do
    params = %{"state" => oidc_provider}

    redirect(conn, to: Routes.o_auth_path(conn, :handle_request, "oidc", params))
  end

  @doc """
  Prepares OAuth request to a provider for Ueberauth.
  """
  def prepare_request(
        %Plug.Conn{} = conn,
        %{"provider" => provider, "authorization" => auth_params}
      ) do
    params =
      ["state", "provider_url"]
      |> Enum.reduce(%{}, fn key, params -> put_if_present(params, key, auth_params[key]) end)
      |> process_provider_url()

    redirect(conn, to: Routes.o_auth_path(conn, :handle_request, provider, params))
  end

  @doc """
  Handles those authorization requests which can not be handled by registered
  Ueberauth strategies.
  """
  def handle_request(%Plug.Conn{} = conn, %{"provider" => provider}) do
    message =
      if provider, do: "Unsupported OAuth provider: #{provider}.", else: "Bad OAuth request."

    error_resp(conn, :bad_request, message)
  end

  @doc """
  Handles a failure from external OAuth provider.
  """
  def handle_callback(
        %Plug.Conn{
          assigns: %{ueberauth_failure: %Failure{errors: [%Failure.Error{} = error | _]}}
        } = conn,
        _params
      ) do
    error_resp(conn, :bad_request, "#{error.message_key}: #{error.message}")
  end

  @doc """
  Handles successful authorization and registers a new user from external OAuth
  provider.
  """
  @spec handle_callback(Plug.Conn.t(), map) :: Plug.Conn.t()
  def handle_callback(
        %Plug.Conn{assigns: %{ueberauth_auth: %Auth{info: %Auth.Info{} = info}}} = conn,
        %{"provider" => provider} = params
      ) do
    info = Map.delete(info, :__struct__)
    username = info.nickname || info.name
    {provider, client_name, scopes} = app_attrs(provider, params["state"])

    with {:ok, %App{client_id: client_id, redirect_uris: redirect_uri, scopes: scope} = app} <-
           get_or_create_app(provider, client_name, scopes),
         {:ok, registration} <-
           Registration.get_or_create(%{username: username, provider: app.client_name}, info) do
      auth_params = %{"client_id" => client_id, "redirect_uri" => redirect_uri, "scope" => scope}

      case Repo.preload(registration, :user).user do
        %User{} = user ->
          create_authorization(conn, %{"authorization" => auth_params}, user: user)

        nil ->
          registration_params =
            Map.merge(auth_params, %{
              "username" => username,
              "provider" => client_name || provider,
              "registration_id" => registration.id
            })

          registration_from_provider(conn, %{"authorization" => registration_params})
      end
    end
  end

  @spec get_or_create_app(String.t(), String.t() | nil, [String.t()]) :: {:ok, App.t()}
  defp get_or_create_app(provider, nil, scopes) do
    case App.get_by(%{provider: provider, client_name: provider}) do
      %App{} = app ->
        {:ok, app}

      nil ->
        app_credentials =
          case provider do
            "oidc_" <> oidc_provider -> Config.oidc_provider_opts(oidc_provider)
            provider -> Config.oauth2_provider_opts(provider)
          end

        App.create_from_provider(%{
          client_name: provider,
          provider: provider,
          redirect_uris: "#{Config.base_url()}auth/#{provider}/callback",
          scopes: scopes,
          client_id: app_credentials[:client_id],
          client_secret: app_credentials[:client_secret],
          trusted: true
        })
    end
  end

  defp get_or_create_app(provider, client_name, _scopes) do
    {:ok, App.get_by(%{provider: provider, client_name: client_name})}
  end

  ####################
  ### OAuth Server ###
  ####################

  @doc """
  Renders registration form after authentication via external provider.
  """
  @spec registration_from_provider(Plug.Conn.t(), map) :: Plug.Conn.t()
  def registration_from_provider(%Plug.Conn{} = conn, %{"authorization" => auth_params}) do
    render(conn, "register_from_provider.html", %{
      client_id: auth_params["client_id"],
      redirect_uri: auth_params["redirect_uri"],
      state: auth_params["state"],
      scopes: Scopes.fetch_scopes(auth_params, []),
      username: auth_params["username"],
      provider: auth_params["provider"],
      registration_id: auth_params["registration_id"]
    })
  end

  @doc """
  Renders registration form for local users.
  """
  @spec registration_local(Plug.Conn.t(), map) :: Plug.Conn.t()
  def registration_local(%Plug.Conn{} = conn, _params) do
    render(conn, "register_local.html")
  end

  @doc """
  Connects an authorized via external provider user to an existed local user.
  """
  @spec register(Plug.Conn.t(), map) :: Plug.Conn.t()
  def register(
        %Plug.Conn{} = conn,
        %{"authorization" => auth_params, "op" => "connect"} = params
      ) do
    with registration_id when not is_nil(registration_id) <- auth_params["registration_id"],
         %Registration{} = registration <- Registration.get_by(%{id: registration_id}),
         {_, {:ok, auth}} <- {:create_authorization, do_create_authorization(conn, params)},
         %User{} = user <- Repo.preload(auth, :user).user,
         {:ok, _updated_registration} <- Registration.bind_to_user(registration, user) do
      post_create_authorization(conn, auth, params)
    else
      {:create_authorization, error} ->
        handle_create_authorization_error(conn, error, params)

      _ ->
        {:web_register, :generic_error}
    end
  end

  @doc """
  Registers an authorized via external provider user as a new local user.
  """
  def register(
        %Plug.Conn{} = conn,
        %{"authorization" => auth_params, "op" => "register_from_provider"} = params
      ) do
    with registration_id when not is_nil(registration_id) <- auth_params["registration_id"],
         %Registration{} = registration <- Registration.get_by(%{id: registration_id}),
         {:ok, user} <- Authenticator.create_user_from_registration(registration, params) do
      create_authorization(conn, params, user: user)
    end
  end

  @doc """
  Registers a new local user.
  """
  def register(
        %Plug.Conn{} = conn,
        %{"authorization" => auth_params, "op" => "register_local"} = params
      ) do
    with true <- auth_params["password"] == auth_params["password_confirmation"],
         app <- App.get_by(%{client_name: "local", provider: "local"}),
         auth_params <-
           Map.merge(auth_params, %{
             "client_id" => app.client_id,
             "redirect_uri" => app.redirect_uris,
             "scope" => app.scopes,
             "provider" => "local"
           }),
         {:ok, registration} <-
           Registration.create(%{username: auth_params["username"], provider: "local"}),
         params <- %{params | "authorization" => auth_params},
         {:ok, user} <- Authenticator.create_user_from_registration(registration, params) do
      create_authorization(conn, params, user: user)
    else
      false ->
        {:web_register, :password_confirmation}

      {:error, %Ecto.Changeset{} = error} ->
        client = params["client"] || "web"
        {:"#{client}_register", error}
    end
  end

  @doc """
  Registers a new local user (for REST API clients).
  """
  def register(%Plug.Conn{} = conn, _params) do
    case Utils.fetch_user_credentials(conn) do
      {username, password} when is_binary(username) and is_binary(password) ->
        params = %{
          "op" => "register_local",
          "client" => "api",
          "authorization" => %{
            "username" => username,
            "password" => password,
            "password_confirmation" => password
          }
        }

        register(conn, params)

      _ ->
        {:api_register, :invalid_credentials}
    end
  end

  @doc """
  Authentication from external provider.
  Note: is only called from error-handling methods with `conn.params` as 2nd arg
  """
  def authorize(%Plug.Conn{} = conn, %{"authorization" => _} = params) do
    {auth_attrs, params} = Map.pop(params, "authorization")

    authorize(conn, Map.merge(params, auth_attrs))
  end

  @doc """
  Authentication from external provider.
  """
  @spec authorize(Plug.Conn.t(), map) :: Plug.Conn.t()
  def authorize(%Plug.Conn{} = conn, %{"client_id" => _, "redirect_uri" => _} = params) do
    do_authorize(conn, params)
  end

  @doc """
  Local authentication.
  """
  def authorize(%Plug.Conn{} = conn, params) do
    app = App.get_by(%{client_name: "local", provider: "local"})

    do_authorize(
      conn,
      Map.merge(params, %{"client_id" => app.client_id, "redirect_uri" => app.redirect_uris})
    )
  end

  defp do_authorize(
         %Plug.Conn{} = conn,
         %{"client_id" => client_id, "redirect_uri" => redirect_uri} = params
       ) do
    app = App.get_by(%{client_id: client_id})
    available_scopes = (app && app.scopes) || []
    scopes = Scopes.fetch_scopes(params, available_scopes)

    render(conn, "authorize.html", %{
      app: app,
      response_type: params["response_type"] || "password",
      client_id: client_id,
      available_scopes: available_scopes,
      scopes: scopes,
      redirect_uri: redirect_uri,
      state: params["state"],
      params: params
    })
  end

  @spec create_authorization(Plug.Conn.t(), map, keyword) :: Plug.Conn.t()
  def create_authorization(
        %Plug.Conn{} = conn,
        %{"authorization" => _} = params,
        opts \\ []
      ) do
    case do_create_authorization(conn, params, opts[:user]) do
      {:ok, auth} ->
        post_create_authorization(conn, auth, params)

      error ->
        handle_create_authorization_error(conn, error, params)
    end
  end

  @spec do_create_authorization(Plug.Conn.t(), map, User.t() | nil) ::
          {:ok, Authorization.t()} | {:error, Ecto.Changeset.t()}
  defp do_create_authorization(
         %Plug.Conn{} = conn,
         %{
           "authorization" =>
             %{"client_id" => client_id, "redirect_uri" => redirect_uri} = auth_params
         } = params,
         user \\ nil
       ) do
    with {:ok, %User{} = user} <-
           (user && {:ok, user}) || Authenticator.get_user(conn, params),
         %App{} = app <- App.get_by(%{client_id: client_id}),
         true <- redirect_uri in String.split(app.redirect_uris),
         {:ok, scopes} <- Utils.validate_scopes(app, auth_params) do
      Authorization.create(app, user, scopes)
    end
  end

  defp post_create_authorization(
         %Plug.Conn{} = conn,
         %Authorization{} = auth,
         %{"authorization" => %{"redirect_uri" => @oob_token_redirect_uri}}
       ) do
    text(conn, "Authorization code: #{auth.code}")
  end

  defp post_create_authorization(
         %Plug.Conn{} = conn,
         %Authorization{code: auth_code} = auth,
         %{"authorization" => %{"redirect_uri" => redirect_uri} = auth_params}
       ) do
    app = Repo.preload(auth, :app).app

    case app.provider do
      "local" ->
        # server mode
        if redirect_uri in String.split(app.redirect_uris) do
          redirect_uri = redirect_uri(conn, redirect_uri)
          url_params = put_if_present(%{"code" => auth_code}, "state", auth_params["state"])
          redirect_uri = Utils.append_uri_params(redirect_uri, url_params)

          redirect(conn, external: redirect_uri)
        else
          redirect(conn, external: redirect_uri(conn, redirect_uri))
        end

      _ ->
        # consumer mode
        redirect_uri = uri_with_params(redirect_uri(conn, "."), %{"code" => auth.code})

        redirect(conn, external: redirect_uri)
    end
  end

  defp handle_create_authorization_error(
         %Plug.Conn{} = conn,
         {:error, _},
         %{"authorization" => _} = params
       ) do
    conn
    |> put_flash(:error, "Invalid credentials")
    |> put_status(:unauthorized)
    |> authorize(params)
  end

  @spec handle_create_authorization_error(Plug.Conn.t(), any, map) :: Plug.Conn.t()
  defp handle_create_authorization_error(%Plug.Conn{} = conn, _error, %{"authorization" => _}) do
    render_invalid_credentials_error(conn)
  end

  @spec render_invalid_credentials_error(Plug.Conn.t()) :: Plug.Conn.t()
  defp render_invalid_credentials_error(%Plug.Conn{} = conn) do
    error_resp(conn, :bad_request, "Invalid client_id, client_secret or redirect_uri.")
  end

  @spec login(Plug.Conn.t(), map) :: Plug.Conn.t()
  def login(%Plug.Conn{} = conn, %{"code" => auth_code}) do
    with %Authorization{} = auth <- Authorization.get_by(%{code: auth_code}),
         %App{} = app <- Repo.preload(auth, :app).app,
         {:ok, token} <- Token.exchange_token(app, auth) do
      conn
      |> put_session(:oauth_access_token, token.access_token)
      |> json(Token.serialize(token))
    end
  end

  @doc """
  Exchanges token for the Authorization Code strategy:
  http://tools.ietf.org/html/rfc6749#section-1.3.1
  """
  @spec exchange_token(Plug.Conn.t(), map) :: Plug.Conn.t()
  def exchange_token(
        %Plug.Conn{} = conn,
        %{"grant_type" => "authorization_code", "code" => auth_code}
      ) do
    with %App{} = app <- Utils.fetch_app(conn),
         auth_code <- Utils.ensure_padding(auth_code),
         {:ok, auth} <- Authorization.get_by_code(app, auth_code),
         {:ok, token} <- Token.exchange_token(app, auth) do
      response_attrs = %{created_at: Token.format_creation_date(token.inserted_at)}

      json(conn, Token.serialize(token, response_attrs))
    else
      _error ->
        error_resp(conn, :unauthorized, "Invalid credentials.")
    end
  end

  @doc """
  Exchanges token for the Refresh Token strategy:
  https://tools.ietf.org/html/rfc6749#section-1.5
  """
  def exchange_token(
        %Plug.Conn{} = conn,
        %{"grant_type" => "refresh_token", "refresh_token" => refresh_token}
      ) do
    with %App{} = app <-
           Utils.fetch_app(conn) || App.get_by(%{client_name: "local", provider: "local"}),
         {:ok, token} <- Token.get_by_refresh_token(app, refresh_token),
         {:ok, token} <- RefreshToken.grant(token) do
      response_attrs = %{created_at: Token.format_creation_date(token.inserted_at)}

      json(conn, Token.serialize(token, response_attrs))
    else
      _error ->
        error_resp(conn, :unauthorized, "Invalid credentials.")
    end
  end

  @doc """
  Exchanges token for the Resource Owner Password Credentials Authorization strategy:
  http://tools.ietf.org/html/rfc6749#section-1.3.3
  """
  def exchange_token(%Plug.Conn{} = conn, %{"grant_type" => "password"} = params) do
    with {:ok, user} <- Authenticator.get_user(conn, params),
         %App{} = app <- App.get_by(%{client_name: "local", provider: "local"}),
         {:ok, scopes} <- Utils.validate_scopes(app, params),
         {:ok, auth} <- Authorization.create(app, user, scopes),
         {:ok, token} <- Token.exchange_token(app, auth) do
      json(conn, Token.serialize(token))
    else
      _error ->
        error_resp(conn, :unauthorized, "Invalid credentials.")
    end
  end

  @doc """
  Exchanges token for the Client Credentials strategy:
  http://tools.ietf.org/html/rfc6749#section-1.3.4
  """
  def exchange_token(%Plug.Conn{} = conn, %{"grant_type" => "client_credentials"}) do
    with %App{} = app <- App.get_by(%{client_name: "local", provider: "local"}),
         {:ok, auth} <- Authorization.create(app, %User{}),
         {:ok, token} <- Token.exchange_token(app, auth) do
      json(conn, Token.serialize_for_client_credentials(token))
    else
      _error ->
        error_resp(conn, :unauthorized, "Invalid credentials.")
    end
  end

  def exchange_token(%Plug.Conn{} = conn, _params) do
    error_resp(conn, :unauthorized, "Invalid credentials.")
  end

  @doc """
  Revokes token.
  """
  @spec revoke_token(Plug.Conn.t(), map) :: Plug.Conn.t()
  def revoke_token(%Plug.Conn{} = conn, %{"access_token" => _} = params) do
    with %App{} = app <- Utils.fetch_app(conn),
         {:ok, _token} <- RevokeToken.revoke(app, params) do
      json(conn, %{})
    else
      _error ->
        # RFC 7009: invalid tokens [in the request] do not cause an error response
        json(conn, %{})
    end
  end

  def revoke_token(%Plug.Conn{} = conn, _params) do
    error_resp(conn, :bad_request, "Bad request.")
  end

  defp error_resp(%Plug.Conn{} = conn, status, body) do
    conn
    |> send_resp(status, body)
    |> halt()
  end

  @spec app_attrs(String.t(), String.t() | nil) :: {String.t(), String.t() | nil, [String.t()]}
  # OpenID Connect provider
  defp app_attrs("oidc", oidc_provider), do: {"oidc_#{oidc_provider}", nil, @oidc_default_scopes}
  # Sinlge instance OAuth2 provider (eg. Gitlab)
  defp app_attrs(provider, nil), do: {provider, nil, @oauth_default_scopes}
  # Multiple instances OAuth2 provider (eg. Pleroma)
  defp app_attrs(provider, provider_url),
    do: {provider, App.get_provider(provider_url), @oauth_default_scopes}

  # process redirect_uri for local auth app
  @spec redirect_uri(Plug.Conn.t(), String.t()) :: String.t()
  defp redirect_uri(%Plug.Conn{} = conn, "."), do: Routes.o_auth_url(conn, :login)
  defp redirect_uri(%Plug.Conn{}, redirect_uri), do: redirect_uri

  @spec uri_with_params(String.t(), map) :: String.t()
  defp uri_with_params(uri, params) do
    uri
    |> URI.parse()
    |> Map.put(:query, URI.encode_query(params))
    |> URI.to_string()
  end

  @spec put_if_present(map, atom | String.t(), String.t() | nil) :: map
  defp put_if_present(map, _param_name, nil), do: map
  defp put_if_present(map, _param_name, ""), do: map
  defp put_if_present(map, name, value), do: Map.put(map, name, value)

  @spec process_provider_url(map) :: map
  defp process_provider_url(%{"provider_url" => provider_url} = params) do
    provider_url =
      case provider_url = String.downcase(provider_url) do
        "http://" <> _ -> provider_url
        "https://" <> _ -> provider_url
        _ -> "https://#{provider_url}"
      end

    Map.put(params, "provider_url", provider_url)
  end

  defp process_provider_url(params), do: params
end
