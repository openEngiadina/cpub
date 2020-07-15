defmodule CPub.Web.Endpoint do
  use Phoenix.Endpoint, otp_app: :cpub

  alias CPub.Config

  socket "/socket", CPub.Web.UserSocket,
    websocket: true,
    longpoll: false

  # Serve at "/" the static files from "priv/static" directory.
  #
  # You should set gzip to true if you are running phx.digest
  # when deploying your static files in production.
  plug Plug.Static,
    at: "/",
    from: :cpub,
    gzip: false,
    only: ~w(css fonts images js favicon.ico robots.txt)

  # Code reloading can be explicitly enabled under the
  # :code_reloader configuration of your endpoint.
  if code_reloading? do
    plug Phoenix.CodeReloader
  end

  plug Plug.RequestId
  plug Plug.Logger

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json, CPub.Web.RDFParser],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head

  # The session will be stored in the cookie and signed,
  # this means its contents can be read but not tampered with.
  # Set :encryption_salt if you would also like to encrypt it.
  # plug Plug.Session,
  #   store: :cookie,
  #   key: Config.cookie_name(),
  #   signing_salt: Config.cookie_signing_salt(),
  #   secure: Config.cookie_secure?(),
  #   extra: Config.cookie_extra_attrs()

  plug Plug.Session,
    store: :cookie,
    key: "_cpub_key",
    signing_salt: "uME3vEPr"

  plug Corsica,
    origins: "*",
    allow_headers: :all,
    expose_headers: ~w(Location)

  plug CPub.Web.Router
end
