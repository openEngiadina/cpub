# Changelog

## [UNRELEASED]

## Changed

- Use the Erlang/OTP mnesia database instead of PostgresSQL
- Use [elixir-eris](https://gitlab.com/openengiadina/elixir-eris/) library for ERIS encoding and update to v0.2.0 of encoding

## [0.2.0] - 2020-08-11

### Added

- Accept data encoded as RDF/JSON
- OAuth 2.0 server for authorization
- Authentication via OpenID Connect and with existing Pleroma/Mastodon instances
- Support for [Content-addressable RDF](https://openengiadina.net/papers/content-addressable-rdf.html)
- [ERIS](https://openengiadina.net/papers/eris.html) encoding for content-addressing

## [0.1.0] - 2020-03-09

Initial alpha release.

### Added

- Initial ActivityPub Client-to-Server (C2S) protocol (with RDF/Turtle
  serialization)
- Expose collections of a activities as Linked Data Platform BasicContainer and
  ActivityStreams Collections
- Authentication with Basic Auth
