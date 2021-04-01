# SPDX-FileCopyrightText: 2020 pukkamustard <pukkamustard@posteo.net>
#
# SPDX-License-Identifier: AGPL-3.0-or-later

use Mix.Config

# For development, we disable any cache and enable
# debugging and code reloading.
#
# The watchers configuration can be used to run external
# watchers to your application. For example, we use it
# with webpack to recompile .js and .css sources.

port = System.get_env("PORT") || 4000

config :cpub,
  namespace: CPub,
  base_url: System.get_env("BASE_URL") || "http://localhost:#{port}/"

config :cpub, CPub.Web.Endpoint,
  http: [port: port],
  debug_errors: true,
  code_reloader: true,
  check_origin: false,
  watchers: []

# config :cpub, :http,
#   proxy_url: "127.0.0.1:9150"

# ## SSL Support
#
# In order to use HTTPS in development, a self-signed
# certificate can be generated by running the following
# Mix task:
#
#     mix phx.gen.cert
#
# Note that this task requires Erlang/OTP 20 or later.
# Run `mix help phx.gen.cert` for more information.
#
# The `http:` config above can be replaced with:
#
#     https: [
#       port: 4001,
#       cipher_suite: :strong,
#       keyfile: "priv/cert/selfsigned_key.pem",
#       certfile: "priv/cert/selfsigned.pem"
#     ],
#
# If desired, both `http:` and `https:` keys can be
# configured to run both http and https servers on
# different ports.

# Do not itimestamps in development logs
config :logger, :console,
  format: "[$level] $message $metadata\n",
  metadata: [:error]

# Set a higher stacktrace during development. Avoid configuring such
# in production as building large stacktraces may be expensive.
config :phoenix, :stacktrace_depth, 20

# Initialize plugs at runtime for faster development compilation
config :phoenix, :plug_init_mode, :runtime

# Configure your database
config :cpub, CPub.Repo,
  username: "postgres",
  password: "postgres",
  database: "cpub_dev",
  hostname: "localhost",
  pool_size: 10

# Configure Joken
config :joken, default_signer: "secret"

config :joken,
  rs256: [
    signer_alg: "RS256",
    key_pem: """
    -----BEGIN RSA PRIVATE KEY-----
    MIIEowIBAAKCAQEA3aC20H/E2XQj7E+sHXNOYpaBvZ30kdUU84fetOh9oWnWVebD
    +LGIgD1GIvu2xDkeZnCjih49xG2UYkLBtSrhQoFCwVpfaHUOIbNiVhzYRdZ9rsK9
    mDcNzvwyn542BhbFpwq39lEkglkexduGJGCZrUpMWzR5kY5Z+HYZpcs52VL6ue8t
    tav0gKG7Q+qhaqPm931LUoL6ArPb4tIplOKzHxv2/81aa9gd/rJrj6H4h5ebs6ZB
    /p8e1+NDnU/03k71KwsF9KjVvCbFA7DBSh8ewqDde5FjtOGzT0NKDhRgQdUOFBEe
    xXFGZlIGenxRl/7fy0mWrKoVRf8ezc3QOP1bPwIDAQABAoIBABv4X3oa1e4XsTzu
    pSsmVTsuAXu7xpTtDnLZr+qm+Mv5Pnqi4BKv3SlKEmLx35QOHV8SUiFpRaRXrAVm
    pWnG2pz5EUKztBzLwRfRutRhWY4ezsfSffkK4axAuebZIbpM/27gdG0aun/U3YRc
    +yX2Jw7utIpCKiGLlKE9zmjVKBzcFty3pwyAT3UcTpSJ2GuhGgW9BIgKb8t24MDz
    iswDnOXZropV8N2aU8aaikcLUjkjUr5uBhnx7ahIgL8WdSFVUGnpwTubIWqjuFC9
    cmWl21VzYVDQTLYmyS68H+7LEOWtfj0tuGxIiYxwiTTUb6Z4O0ZzU9bxlyVWFidi
    x7Qy8okCgYEA/Irf9GCIg+GbzrA7pZB9JCaYkiw8qNcnkd5X4gAFkOsgWJFZB9X2
    qNQDPrKmfRjHUL4SV9Y2QyfcusoZk4nTIgbnH3RVFLR4+N9QWvDDYxoxBTf7cp4X
    PTAUOlP41SEVdXS3o082FVJWE/UobKYm8cf4CGzd6//utcy2QfZZhu0CgYEA4Kl8
    3IkAhyQPX7ioTK7NmbeiwdhW+V0cjCKdgp6pqfkYXFl0UP14LgrTTKHgm6Ohh1p0
    uuVWNOoN/izHoQD2dmdE1AsCeYIWgf+8wUAv2CegIum+z/zmZnmlRotuyBw/lVIg
    c3H9+Y0/5ZpK/xIZPs5nXhSLgDAU0jGgRAoKWVsCgYBjCX88UeMXfRFiJACwNBKv
    a6dno4uCVyYAcWabjZChPWQo948noIQjv0kqfFsIMgBwLKn64lnTSj2ozvrqviEb
    dgOLdU6sWP4b80+K6mJlae8RcdvdHhxU9ZbpLOcnhdrpfgVKORUnlWuGVh0tRpd9
    OAOQIkmBdJPDne1XvulrHQKBgAuC47DxHCPQhzEiZw02z7YWoLJKAXrZeIL9qxBs
    TMk2yDbDJqCXvDavu0/r43RWGAq1adHBun8PlxP0+22WfQpoFDDBN6k+LyUOE3/b
    aBgtP5lKXMqPbMbHaN6Kemyqdd+Sy7LenmLRB/sdwsX7CWwca1N4vgUdcZOrk0ip
    MwqNAoGBAMroAmMAlWECreynBY2lfyZjLoTHpj14zoG3hlDHuujCLi0mD8UXNur0
    g7mZUdeOKREILutZksenB2wSmpqTxja3RW4qY8fAW4L+Nyyu9qtMro5n9IKV7CEu
    eFUVUwO4RFVJInyNgdoCseb7jl//mGxcx8xonWyCwMm0dsgfE3IT
    -----END RSA PRIVATE KEY-----
    """
  ]

# Enable OAuth2 debug
config :oauth2, debug: true
