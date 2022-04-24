<!--
SPDX-FileCopyrightText: 2020 pukkamustard <pukkamustard@posteo.net>

SPDX-License-Identifier: CC0-1.0
-->

# Changelog

## [0.3.0] - 2022-04-24

Initial support of the ActivityPub Client-to-Server protocol.

### Added

- Add initial support of the [Client to Server (C2S)](https://www.w3.org/TR/activitypub/#client-to-server-interactions) protocol.
- Add [JSON-LD](https://json-ld.org/) serialization and use as default serialization.
- Add support for the [NodeInfo](https://github.com/jhass/nodeinfo/blob/main/PROTOCOL.md) protocol.
- Add support for the [WebFinger](https://datatracker.ietf.org/doc/html/rfc7033) protocol.
- Add `/api/whoami` endpoint from the pump.io protocol.
- Add support for dereferencing [Magnet URIs](https://en.wikipedia.org/wiki/Magnet_URI_scheme).

### Changed

- Use the Erlang/OTP mnesia database instead of PostgresSQL
- Use [elixir-eris](https://codeberg.org/openEngiadina/elixir-eris/) library for ERIS encoding and update to v0.2.0 of encoding

## [0.2.0] - 2020-08-11

### Added

- Accept data encoded as RDF/JSON
- OAuth 2.0 server for authorization
- Authentication via OpenID Connect and with existing Pleroma/Mastodon instances
- Support for [Content-addressable RDF](http://purl.org/ca-rdf)
- [ERIS](http://purl.org/eris) encoding for content-addressing

## [0.1.0] - 2020-03-09

Initial alpha release.

### Added

- Initial ActivityPub Client-to-Server (C2S) protocol (with RDF/Turtle
  serialization)
- Expose collections of a activities as Linked Data Platform BasicContainer and
  ActivityStreams Collections
- Authentication with Basic Auth
