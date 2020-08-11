# Architecture

A high-level overview of the CPub architecture.

## Data schema

The basic data entities are objects (see `CPub.Object`). Objects are content-addressed `RDF.FragmentGraph` (see [Content-addressable RDF](https://openengiadina.net/papers/content-addressable-rdf.html))

Activities (`CPub.ActivityPub.Activity`) are special objects that correspond to
ActivityStream activities. The database schema for activities may be
seen as a special index of objects that are activities. 
