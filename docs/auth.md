<!--
SPDX-FileCopyrightText: 2020 pukkamustard <pukkamustard@posteo.net>

SPDX-License-Identifier: CC-BY-SA-4.0
-->

# Authentication and Authorization

Certain requests to resources on CPub need to be authorized. CPub uses the [The OAuth 2.0 Authorization Framework](https://tools.ietf.org/html/rfc6749) for handling authorization.

Following OAuth 2.0 flows are supported:

- [Authorization code](https://tools.ietf.org/html/rfc6749#section-1.3.1)
- [Resource Owner Password Credentials](https://tools.ietf.org/html/rfc6749#section-1.3.3)
- [Refreshing an Access Token](https://tools.ietf.org/html/rfc6749#section-6)

Authorization (in form of an OAuth 2.0 Access Token) is granted after a user has authenticated.

## Authorization (OAuth 2.0)

The OAuth 2.0 endpoints are:

- Authorizatoin endpoint: `/oauth/authorize`
- Token endpoint: `/oauth/token`

Access tokens are valid for 60 days.

For the `Authorization Code` and `Resource Owner Password Credentials` flows a refresh token is issued which can be used to get a new access token. The refresh token can be used until the authorization is revoked by the user.

### Client registration

The `Authorization Code` flow requires a OAuth client to be registered.

Clients can be registered using [OAuth 2.0 Dynamic Client Registration Protocol (RFC 7591)](https://tools.ietf.org/html/rfc7591) at the endpoint `/oauth/clients`.

See the [Demonstration](demo.md) for an example.

## Authentication

CPub support authentication via:

- an internally stored username and password
- an OpenID Connect provider
- a Pleroma/Mastodon compatible OAuth 2.0 server

The interactive authentication endpoint is at: `/auth/login`.

### Internal username and password

Users can sign up with a username and password at the endpoint: `/auth/register`.

### OpenID Connect

Users can authenticate with any [OpenID Connect Core 1.0](https://openid.net/specs/openid-connect-core-1_0.html) provider.

An OAuth 2.0 client must be registered for CPub at the provider. The redirect uri used by CPub is `/auth/oidc/callback`. The only scope required is `openid`.

The client id and client secret (if provider requires) must be configured in CPub from the Elixir shell:

```
  CPub.Web.Authentication.OAuthClient.create(%{
    provider: :oidc,
    site: "http://localhost:8080/auth/realms/cpub-test/",
    client_id: "something-something-something",
    client_secret: "secret-secret-secret-secret",
    display_name: "Keycloak"
  })
```

Where the fields are:

- `provider`: must be `:oidc` to indicate that the client is an OpenID Connect client.
- `site`: the URL to the OpenID Connect provider.
- `client_id`: OAuth 2.0 client id
- `client_secret`: OAuth 2.0 client secret (optional). If defined it will be used when fetching the access/id token from the provider.
- `display_name`: Name of the provider to display on login page (optional). If present the provider will be shown on the login page.

OpenID Connect has been tested with [Keycloak](https://www.keycloak.org/), [Gitlab](https://gitlab.com/) and [Azure Active Directory B2C](https://docs.microsoft.com/en-us/azure/active-directory-b2c/openid-connect).

TODO Implement a nice UI from which this can be setup.

### Pleroma/Mastodon

To authenticate with an existing Pleroma/Mastodon server, enter the URL of the instance in the login field.

TODO Implement a WebFinger client so that users can simply enter their ActivityPub handle and be authenticated with the correct instance.
