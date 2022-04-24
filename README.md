<!--
SPDX-FileCopyrightText: 2020 pukkamustard <pukkamustard@posteo.net>

SPDX-License-Identifier: CC0-1.0
-->

# CPub

CPub is an experimental [ActivityPub](https://www.w3.org/TR/activitypub/) server that uses Semantic Web ideas.

CPub was developed for the [openEngiadina](https://openengiadina.net) project as a platform for open local knowledge.

See also [docs/cpub.md](docs/cpub.md) for more information.

## Quick start

Requirements:

  - Erlang/OTP
  - Elixir

To start the CPub server:

  * Install dependencies with `mix deps.get`
  * Start CPub with an Elixir shell `iex -S mix phx.server`

This will start a shell where you can interact with CPub as well as start the
HTTP server at [`localhost:4000`](http://localhost:4000/public).

See the [example](docs/demo.org) on how to create a user and some data.

## Release

Releases are tagged commits on the `main` branch. To make a new release:

- [ ] Make sure Changelog is up-to-date
- [ ] Update version in Changelog and `mix.exs`
- [ ] Conclude merge with `git commit`
- [ ] Add a git tag with `git tag -a v0.x -m "v0.x"`
- [ ] Push to upstream branch with `git push upstream main` and `git push upstream main --tags`

## Documentation

See the [docs](docs/) folder for documentation. Documentation is also available [online](https://openengiadina.codeberg.page/cpub).

## Acknowledgments

CPub was developed as part of the [openEngiadina](https://openengiadina.net) project and has been supported by the [NLnet Foundation](https://nlnet.nl/) trough the [NGI0 Discovery Fund](https://nlnet.nl/discovery/).
