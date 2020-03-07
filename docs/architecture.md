# Architecture

A high-level overview of the CPub architecture.

## Data schema

The basic data entities are objects (see `CPub.Object`). Objects are identified
by an [UUID](`Ecto.UUID`) and hold an `RDF.Description` (i.e. a set of triples
with the same subject). Objects are immutable.

Activities (`CPub.Activity`) are special objects that correspond to
ActivityStream activities. They current database schema for activities may be
seen as a special index of objects that are activities. 

Objects are accessed by their identifier (which is random and not guessable
UUID). Knowing the id is enough to grant access to the object. There is no
listing of all objects, so by default nobody has access to anything.

`CPub.User` may be seen as a collection of pointers to special objects. For
example it servers as a pointer for all activities that have been created by the
user (the outbox) or all activities that have been addressed to the user (the inbox).
The `CPub.User` pointers are accessible at a known location (e.g.
`users/alice/inbox`). Access to these locations is only granted to the
respective authenticated user.
