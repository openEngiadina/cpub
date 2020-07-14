# Authentication and Authorization

Certain requests to ressources on CPub need to be authorized. CPub uses the [The OAuth 2.0 Authorization Framework](https://tools.ietf.org/html/rfc6749) for handling authorization.

Following OAuth 2.0 flows are supported:

- [Authorization code](https://tools.ietf.org/html/rfc6749#section-1.3.1)
- [Implicit](https://tools.ietf.org/html/rfc6749#section-1.3.2)
- [Resource Owner Password Credentials](https://tools.ietf.org/html/rfc6749#section-1.3.3)
- [Refreshing an Access Token](https://tools.ietf.org/html/rfc6749#section-6)

<!-- Furthermore CPub implements [OpenID Connect Core 1.0](https://openid.net/specs/openid-connect-core-1_0.html). -->
<!-- and [WebID-OIDC](https://github.com/solid/webid-oidc-spec) -->

Authorization (in form of an OAuth 2.0 Access Token) is granted after a user has authenticated.

## Authorization (OAuth 2.0)

The OAuth 2.0 endpoints are:

- Authorizatoin endpoint: `/oauth/authorize`
- Token endpoint: `/oauth/token`

Access tokens are valid for 60 days.

For the `Authorization Code` and `Resource Owner Password Credentials` flows a refresh token is issued which can be used to get a new access token. The refresh token can be used until the authorization is revoked by the user.

## Authentication

CPub support authentication via:

- Username/Password
<!-- - With an OpenID Connect server -->
<!-- - With a Pleroma/Mastodon compatible OAuth 2.0 server -->
