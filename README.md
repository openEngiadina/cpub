# CPub

CPub is a general [ActivityPub](https://www.w3.org/TR/activitypub/) server built upon Semantic Web ideas. Most notably it also implements a [Linked Data Platform (LDP)](https://www.w3.org/TR/ldp/) and uses [RDF Turtle](https://www.w3.org/TR/turtle/) as serialization format.

The project goals are:

- Develop a general ActivityPub server that can be used to create any kind of structured content.
- Experiment with using Linked Data (RDF) as data model for everything.

CPub is developed as part of the [openEngiadina](https://openengiadina.net/) platform for open local knowledge.

## Quick start

To start the CPub server:

  * Install dependencies with `mix deps.get`
  * Create and migrate your database with `mix ecto.setup`
  * Start CPub with an Elixir shell `iex -S mix phx.server`

This will start a shell where you can interact with CPub as well as start the
HTTP server at [`localhost:4000`](http://localhost:4000/public).

See the [example](docs/example.org) on how to create a user and some data.

## Documentation

See the [docs](docs/) folder for documentation.
