# CPub

CPub is an experimental [ActivityPub](https://www.w3.org/TR/activitypub/) server that uses Semantic Web ideas.

The goals of CPub are:

- Develop a general ActivityPub server that can be used to create any kind of structured content.
- Use Linked Data (RDF) as data model.
- Experiment with content-addressing (see [ERIS](http://purl.org/eris)) and Commutative Replicated Data Types (CRDTs) (see [DMC](http://purl.org/dmc))
- Make deployment of a server as easy as possible (minimal configuration, use the [VMs built-in database](https://www.erlang.org/doc/man/mnesia.html).
- Federate by using the [ActivityPub](https://www.w3.org/TR/activitypub/) protocol and use the ActivityPub Client-to-Server protocol.
- Implement the [Linked Data Platform (LDP)](https://www.w3.org/TR/ldp/) specification.

See the [demo](./demo.md) for an overview of some of the implemented ideas.

CPub was developed for the [openEngiadina](https://openengiadina.net) project as a platform for open local knowledge.

## Status

Development of CPub is discontinued. The openEngiadina project is currently using the XMPP protocol and existing server software (e.g. [ejabberd](http://ejabberd.im/) or [Prosody](https://prosody.im/)). See also [this post](https://inqlab.net/2021-11-12-openengiadina-from-activitypub-to-xmpp.html).

CPub is the result of much research and development into how generic and decentralized data models can be used over the ActivityPub protocol. The work continues within the [openEngiadina](https://openengiadina.net) project with a focus on other protocols. Projects or inviduals who are interested in continuing the development of the ideas within the ActivityPub protocol may be interested in using CPub as a starting point and we would be very happy to support you in such an endeavor. Please feel free to get in contact.

Other related projects include: [SemApps](https://github.com/assemblee-virtuelle/semapps), [rdf-pub](https://gitlab.com/linkedopenactors/rdf-pub/) and [Bonfire](https://bonfirenetworks.org/).

## Acknowledgments

CPub was developed as part of the [openEngiadina](https://openengiadina.net) project and has been supported by the [NLnet Foundation](https://nlnet.nl/) trough the [NGI0 Discovery Fund](https://nlnet.nl/discovery/).
