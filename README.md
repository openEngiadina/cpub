<!--
SPDX-FileCopyrightText: 2020 pukkamustard <pukkamustard@posteo.net>

SPDX-License-Identifier: CC0-1.0
-->

# CPub

CPub is a general [ActivityPub](https://www.w3.org/TR/activitypub/) server built upon Semantic Web ideas. Most notably it also implements a [Linked Data Platform (LDP)](https://www.w3.org/TR/ldp/) and uses [RDF Turtle](https://www.w3.org/TR/turtle/) as serialization format.

The project goals are:

- Develop a general ActivityPub server that can be used to create any kind of structured content.
- Experiment with using Linked Data (RDF) as data model for everything.

CPub is developed as part of the [openEngiadina](https://openengiadina.net/) platform for open local knowledge.

## Quick start

Requirements:

  - Erlang/OTP
  - Elixir

To start the CPub server:

  * Install dependencies with `mix deps.get`
  * Start CPub with an Elixir shell `iex -S mix phx.server`

This will start a shell where you can interact with CPub as well as start the
HTTP server at [`localhost:4000`](http://localhost:4000/public).

See the [example](docs/example.org) on how to create a user and some data.

## Release

Releases are tagged commits on the `main` branch. To make a new release:

- [ ] Make sure Changelog is up-to-date
- [ ] Start a merge of `develop` into `main` with `git merge --no-ff --no-commit develop`. 
- [ ] Update version in Changelog and `mix.exs`
- [ ] Conclude merge with `git commit`
- [ ] Add a git tag with `git tag -a v0.x -m "v0.x"`
- [ ] Push to upstream branch with `git push upstream main` and `git push upstream main --tags`


## Documentation

See the [docs](docs/) folder for documentation.
