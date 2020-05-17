defmodule CPub.Web.OAuth.OAuthController do
  use CPub.Web, :controller

  alias CPub.{Config, Registration, Repo, User}
  alias CPub.Web.OAuth.{App, Authenticator, Authorization, Scopes, Token, Utils}
  alias CPub.Web.OAuth.Token.Strategy.RefreshToken
  alias CPub.Web.OAuth.Token.Strategy.Revoke, as: RevokeToken

  alias Ueberauth.{Auth, Failure}

  @oob_token_redirect_uri "urn:ietf:wg:oauth:2.0:oob"

  action_fallback CPub.Web.OAuth.FallbackController

  plug :fetch_session
  plug :fetch_flash

  #####################################################
  ### OAuth Client (support for external providers) ###
  #####################################################

  if Config.auth_consumer_enabled?(), do: plug(Ueberauth)

  @doc """
  Prepares OAuth request to provider for Ueberauth.
  """
  @spec prepare_request(Plug.Conn.t(), map) :: Plug.Conn.t()
  def prepare_request(
        %Plug.Conn{} = conn,
        %{"provider" => provider, "authorization" => auth_params}
      ) do
    params =
      Enum.reduce(["state", "provider_url"], %{}, fn key, params ->
        if auth_params[key] != "", do: Map.put(params, key, auth_params[key]), else: params
      end)

    redirect(conn, to: Routes.o_auth_path(conn, :handle_request, provider, params))
  end

  @doc """
  Handles those authorization requests which can not be handled by registered
  Ueberauth strategies.
  """
  @spec handle_request(Plug.Conn.t(), map) :: Plug.Conn.t()
  def handle_request(%Plug.Conn{} = conn, %{"provider" => provider}) do
    message =
      if provider, do: "Unsupported OAuth provider: #{provider}.", else: "Bad OAuth request."

    error_resp(conn, :bad_request, message)
  end

  @doc """
  Handles a failure from external OAuth provider.
  """
  # @spec handle_callback(Plug.Conn.t(), map) :: Plug.Conn.t()
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
    client_name = if params["state"], do: App.get_provider(params["state"]), else: nil

    with {:ok, app} <- get_or_create_app(provider, client_name),
         {:ok, registration} <-
           Registration.get_or_create(%{username: username, provider: app.client_name}, info) do
      auth_params = %{
        "client_id" => app.client_id,
        "redirect_uri" => app.redirect_uris,
        "scope" => app.scopes
      }

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

          registration_details(conn, %{"authorization" => registration_params})
      end
    end
  end

  @spec get_or_create_app(String.t(), String.t() | nil) :: {:ok, App.t()}
  defp get_or_create_app(provider, nil) do
    case App.get_by(%{provider: provider, client_name: provider}) do
      %App{} = app ->
        {:ok, app}

      nil ->
        app_credentials = Config.oauth2_provider_credentials(provider)

        App.create_from_provider(%{
          client_name: provider,
          provider: provider,
          redirect_uris: "#{Config.base_url()}auth/#{provider}/callback",
          scopes: ["read"],
          client_id: app_credentials[:client_id],
          client_secret: app_credentials[:client_secret],
          trusted: true
        })
    end
  end

  defp get_or_create_app(provider, client_name) do
    {:ok, App.get_by(%{provider: provider, client_name: client_name})}
  end

  ####################
  ### OAuth Server ###
  ####################

  @spec registration_details(Plug.Conn.t(), map) :: Plug.Conn.t()
  def registration_details(%Plug.Conn{} = conn, %{"authorization" => auth_params}) do
    render(conn, "register.html", %{
      client_id: auth_params["client_id"],
      redirect_uri: auth_params["redirect_uri"],
      state: auth_params["state"],
      scopes: Scopes.fetch_scopes(auth_params, []),
      username: auth_params["username"],
      provider: auth_params["provider"],
      registration_id: auth_params["registration_id"]
    })
  end

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
        {:register, :generic_error}
    end
  end

  def register(
        %Plug.Conn{} = conn,
        %{"authorization" => auth_params, "op" => "register"} = params
      ) do
    with registration_id when not is_nil(registration_id) <- auth_params["registration_id"],
         %Registration{} = registration <- Registration.get_by(%{id: registration_id}),
         {:ok, user} <- Authenticator.create_user_from_registration(conn, registration) do
      create_authorization(conn, params, user: user)
    end
  end

  # Note: is only called from error-handling methods with `conn.params` as 2nd arg
  def authorize(%Plug.Conn{} = conn, %{"authorization" => _} = params) do
    {auth_attrs, params} = Map.pop(params, "authorization")

    authorize(conn, Map.merge(params, auth_attrs))
  end

  @spec authorize(Plug.Conn.t(), map) :: Plug.Conn.t()
  def authorize(%Plug.Conn{} = conn, params) do
    do_authorize(conn, params)
  end

  defp do_authorize(
         %Plug.Conn{} = conn,
         %{"client_id" => client_id, "redirect_uri" => redirect_uri} = params
       ) do
    app = App.get_by(%{client_id: client_id})
    available_scopes = (app && app.scopes) || []
    scopes = Scopes.fetch_scopes(params, available_scopes)

    render(conn, "show.html", %{
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
    {:ok, auth} = do_create_authorization(conn, params, opts[:user])

    post_create_authorization(conn, auth, params)
  end

  @spec do_create_authorization(Plug.Conn.t(), map, User.t() | nil) ::
          {:ok, Authorization.t()} | {:error, Ecto.Changeset.t()}
  defp do_create_authorization(
         %Plug.Conn{} = conn,
         %{
           "authorization" =>
             %{"client_id" => client_id, "redirect_uri" => redirect_uri} = auth_params
         },
         user \\ nil
       ) do
    with {:ok, %User{} = user} <-
           (user && {:ok, user}) || Authenticator.get_user(conn),
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

  @spec exchange_token(Plug.Conn.t(), map) :: Plug.Conn.t()
  def exchange_token(
        %Plug.Conn{} = conn,
        %{"grant_type" => "authorization_code", "code" => auth_code}
      ) do
    # The Authorization Code Strategy: http://tools.ietf.org/html/rfc6749#section-1.3.1
    with {:ok, app} <- Utils.fetch_app(conn),
         auth_code <- Utils.ensure_padding(auth_code),
         {:ok, auth} <- Authorization.get_by_code(app, auth_code),
         {:ok, token} <- Token.exchange_token(app, auth) do
      response_attrs = %{created_at: Token.format_creation_date(token.inserted_at)}

      json(conn, Token.serialize(token, response_attrs))
    else
      _error ->
        render_invalid_credentials_error(conn)
    end
  end

  def exchange_token(
        %Plug.Conn{} = conn,
        %{"grant_type" => "refresh_token", "refresh_token" => refresh_token}
      ) do
    # The Refresh Token Strategy: https://tools.ietf.org/html/rfc6749#section-1.5
    with {:ok, app} <- Utils.fetch_app(conn),
         {:ok, token} <- Token.get_by_refresh_token(app, refresh_token),
         {:ok, token} <- RefreshToken.grant(token) do
      response_attrs = %{created_at: Token.format_creation_date(token.inserted_at)}

      json(conn, Token.serialize(token, response_attrs))
    else
      _error ->
        render_invalid_credentials_error(conn)
    end
  end

  def exchange_token(
        %Plug.Conn{} = conn,
        %{"grant_type" => "password", "name" => _, "password" => _} = params
      ) do
    # The Resource Owner Password Credentials Authorization Strategy:
    # http://tools.ietf.org/html/rfc6749#section-1.3.3
    with {:ok, user} <- Authenticator.get_user(conn),
         {:ok, app} <- Utils.fetch_app(conn),
         {:ok, scopes} <- Utils.validate_scopes(app, params),
         {:ok, auth} <- Authorization.create(app, user, scopes),
         {:ok, token} <- Token.exchange_token(app, auth) do
      json(conn, Token.serialize(token))
    else
      _error ->
        render_invalid_credentials_error(conn)
    end
  end

  def exchange_token(
        %Plug.Conn{} = conn,
        %{"grant_type" => "password", "username" => _, "password" => _} = params
      ) do
    exchange_token(conn, params)
  end

  def exchange_token(
        %Plug.Conn{} = conn,
        %{"grant_type" => "client_credentials"}
      ) do
    # The Client Credentials Strategy: http://tools.ietf.org/html/rfc6749#section-1.3.4
    with {:ok, app} <- Utils.fetch_app(conn),
         {:ok, auth} <- Authorization.create(app, %User{}),
         {:ok, token} <- Token.exchange_token(app, auth) do
      json(conn, Token.serialize_for_client_credentials(token))
    else
      _error ->
        render_invalid_credentials_error(conn)
    end
  end

  def exchange_token(%Plug.Conn{} = conn, _params) do
    error_resp(conn, :bad_request, "Bad request.")
  end

  @spec revoke_token(Plug.Conn.t(), map) :: Plug.Conn.t()
  def revoke_token(%Plug.Conn{} = conn, %{"access_token" => _} = params) do
    with {:ok, app} <- Utils.fetch_app(conn),
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

  @spec put_if_present(map, atom | String.t(), String.t()) :: map
  defp put_if_present(map, _param_name, nil), do: map
  defp put_if_present(map, name, value), do: Map.put(map, name, value)
end
