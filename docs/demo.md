# Demo

A demo of selected features of CPub.

## Create a User

Users can be created from the Elixir shell.

For example we create the user \"alice\" with password \"123\":

``` elixir
{:ok, alice} = CPub.User.create("alice")
{:ok, _registration} = CPub.User.Registration.create_internal(alice, "123")
```

This creates the user, an actor profile, inbox and outbox for the user
and inserts it into the database in a transaction.

```
GET http://localhost:4000/users/alice
```

``` javascript
{
  "@context": [
    "https://www.w3.org/ns/activitystreams#",
    "http://litepub.social/ns#",
    "http://www.w3.org/ns/ldp#"
  ],
  "endpoints": {
    "oauthAuthorizationEndpoint": "http://localhost:4000/oauth/authorize",
    "oauthRegistrationEndpoint": "http://localhost:4000/oauth/clients",
    "oauthTokenEndpoint": "http://localhost:4000/oauth/token"
  },
  "followers": "http://localhost:4000/users/alice/followers",
  "following": "http://localhost:4000/users/alice/following",
  "id": "http://localhost:4000/users/alice",
  "inbox": "http://localhost:4000/users/alice/inbox",
  "outbox": "http://localhost:4000/users/alice/outbox",
  "preferredUsername": "alice",
  "published": "2022-04-23T11:28:01",
  "type": "Person"
}
```

An inbox and outbox has been created for the actor.

The inbox and outbox are protected so that only the user \"alice\" can
access them.

In order to access the inbox and outbox we first need to authenticate
and receive authorization.

## Authentication and Authorization

Some resources (such as user inbox and outbox) are accessible only to
specific users. If a user wants to access such a resource, they need to
authenticate (prove that they are the user) and then receive
authorization to access the route. See [*Authentication and
Authorization*]{.spurious-link target="auth.md"} for a complete
reference on how this works.

In this demo we will use the OAuth 2.0 \"Resource Owner Password
Credentials\" flow. We will authenticate with a username and password
and immediately receive a token (an Access Token in OAuth terminology)
with which we can access the inbox and outbox.

This flow is suitable for clients that are capable of securely handling
user secrets (i.e. password).

Web applications are not capable of securely handling user secrets and
should use the \"Authorization Code\" flow. See the documentation on
[Authentication and Authorization](./auth.md) for more information.

### Resource Owner Password Credentials flow

``` 
POST http://localhost:4000/oauth/token
Content-type: application/json

{"grant_type": "password",
 "username": "alice",
 "password": "123"
}
```

``` javascript
{
  "access_token": "RWGHS3IVQTWLFKACA2NF5BEXZ6AUS7IQHPPC56IVTUFCBBFQ3MPQ",
  "expires_in": 5184000,
  "me": "http://localhost:4000/users/alice",
  "refresh_token": "34VE2PERVH2JAMXUO5DHNCEVPX7YTRAXPM33YLTJHT22F2WRQ57A",
  "token_type": "bearer"
}
```

### Authorization Code

For illustration purposes we demonstrate the OAuth \"Authorization
Code\" flow including dynamic client registration.

#### Client registration

Clients can be dynamically registered using the [OAuth 2.0 Dynamic
Client Registration Protocol (RFC
7591)](https://tools.ietf.org/html/rfc7591):

``` 
POST http://localhost:4000/oauth/clients
Content-type: application/json

{"client_name": "Demo client",
 "redirect_uris": ["https://example.com/"],
 "scope": "read write"
}
```

``` javascript
{
  "client_id": "86ff98ca-b61c-4a5f-ba7b-0668f81af113",
  "client_name": "Demo client",
  "client_secret": "VEJ5SCFUA4VNXNE4CO5EV5DTIW377LVFY3AVOIEINKH52GA73BQQ",
  "redirect_uris": [
    "https://example.com/"
  ],
  "scope": [
    "read",
    "write"
  ]
}
```

#### Authorization request

A user can now be requested to grant authorization to the client by
redirecting to following URL:

<http://localhost:4000/oauth/authorize?client_id=86ff98ca-b61c-4a5f-ba7b-0668f81af113&scope=read+write&response_type=code>

Note how this includes the `client_id`, the requested `scope` and the
`response_type=code`.

The user will be presented with an interface where they can either
\"Accept\" or \"Deny\" the request.

If the request is granted the browser will be redirected to the
`redirect_uri` with an \"Authorization Grant\" that is encoded in the
`code` query parameter:

<https://example.com/?code=A2DWGE3CLKVGA3XXTFFSZJRM7NJMBZKGPLHLUER3UWDIPK32RQDA>

#### Authorization Grant

The Authorization Grant can be exchanged for an access token by making a
call to the token endpoint:

``` 
POST http://localhost:4000/oauth/token
Content-type: application/json

{"grant_type": "authorization_code",
 "code": "A2DWGE3CLKVGA3XXTFFSZJRM7NJMBZKGPLHLUER3UWDIPK32RQDA",
 "client_id": "86ff98ca-b61c-4a5f-ba7b-0668f81af113"}
```

``` javascript
{
  "access_token": "5ULWP3ZLUDZM6UFF55SCQPZRHH45W52SPG4UV4GSYFE2DEPF25GA",
  "expires_in": 5184000,
  "refresh_token": "VZGG2FCYDGXFNTFGIF3Z5GO76VF65QVZE7LSWIMVFQEBKOZQINMQ",
  "token_type": "bearer"
}
```

The returned `access_token` can be used to access protected resources.

## Inbox and Outbox

We can now access Alice\'s inbox by using the \`access~token~\`:

``` 
GET http://localhost:4000/users/alice/inbox
Authorization: Bearer RWGHS3IVQTWLFKACA2NF5BEXZ6AUS7IQHPPC56IVTUFCBBFQ3MPQ
```

``` javascript
{
  "@context": [
    "https://www.w3.org/ns/activitystreams#",
    "http://litepub.social/ns#",
    "http://www.w3.org/ns/ldp#"
  ],
  "id": "http://localhost:4000/users/alice/inbox",
  "totalItems": "0",
  "type": [
    "BasicContainer",
    "OrderedCollection"
  ]
}
```

As well as the outbox:

``` 
GET http://localhost:4000/users/alice/outbox
Authorization: Bearer RWGHS3IVQTWLFKACA2NF5BEXZ6AUS7IQHPPC56IVTUFCBBFQ3MPQ
```

``` javascript
{
  "@context": [
    "https://www.w3.org/ns/activitystreams#",
    "http://litepub.social/ns#",
    "http://www.w3.org/ns/ldp#"
  ],
  "id": "http://localhost:4000/users/alice/outbox",
  "totalItems": "0",
  "type": [
    "BasicContainer",
    "OrderedCollection"
  ]
}
```

Both inbox and outbox are still empty.

Note that the inbox and outbox are both a Linked Data Platform basic
containers and ActivityStreams collection.

## Posting an Activity

We create another user `bob`:

``` elixir
{:ok, bob} = CPub.User.create("bob")
{:ok, _registration} = CPub.User.Registration.create_internal(bob, "123")
```

And get an access token for Bob:

``` 
POST http://localhost:4000/oauth/token
Content-type: application/json

{"grant_type": "password",
 "username": "bob",
 "password": "123"
}
```

``` javascript
{
  "access_token": "GMTHAKCZABOC66AIYEXQV3YAEOFXRSMM37QHKKP6Z2BAYYCH2FNA",
  "expires_in": 5184000,
  "me": "http://localhost:4000/users/bob",
  "refresh_token": "Z3JVRN7YYUD564XVI2NZZZS5L2N6PYSQOWD3YRAAGAIKITQ6U27Q",
  "token_type": "bearer"
}
```

We can get Bob\'s inbox:

``` 
GET http://localhost:4000/users/bob/inbox
Authorization: Bearer GMTHAKCZABOC66AIYEXQV3YAEOFXRSMM37QHKKP6Z2BAYYCH2FNA
```

``` javascript
{
  "@context": [
    "https://www.w3.org/ns/activitystreams#",
    "http://litepub.social/ns#",
    "http://www.w3.org/ns/ldp#"
  ],
  "id": "http://localhost:4000/users/bob/inbox",
  "totalItems": "0",
  "type": [
    "BasicContainer",
    "OrderedCollection"
  ]
}
```

Also empty. Let\'s change that.

Alice can post a note to Bob:

``` 
POST http://localhost:4000/users/alice/outbox
Authorization: Bearer RWGHS3IVQTWLFKACA2NF5BEXZ6AUS7IQHPPC56IVTUFCBBFQ3MPQ
Accept: text/turtle
Content-type: text/turtle

@prefix as: <https://www.w3.org/ns/activitystreams#> .

<>
    a as:Create ;
    as:to <local:bob> ;
    as:object _:object .

_:object
    a as:Note ;
    as:content "Good day!"@en ;
    as:content "Guten Tag!"@de ;
    as:content "Grüezi"@gsw ;
    as:content "Bun di!"@roh .
```

``` javascript
// POST http://localhost:4000/users/alice/outbox
// HTTP/1.1 201 Created
// cache-control: max-age=0, private, must-revalidate
// content-length: 0
// date: Sat, 23 Apr 2022 11:42:58 GMT
// location: http://localhost:4000/uri-res/N2R?urn:erisx2:AAAMOKUACTM4OHXSWPIVSZJDAD7C4GE6GR2Y6IPEESIYM7USXKCOGKANY47P3ZR3JBBIWWPKO47CTPJTUZCVLGGTJRXF3Z6G5A2X4GDXEM
// server: Cowboy
// x-request-id: FuiDzLFI94w236UAAADj
// Request duration: 0.269794s
```

The activity has been created and the IRI of the created activity is
returned in the location header.

Note that we used a special IRI \<local:bob> to address Bob. This is a
temporary hack...stay tuned.

We also use the RDF/Turtle serialization instead of the usual JSON-LD.
CPub also supports posting activities as JSON-LD.

The created activity is content-addressed. The IRI is not a HTTP
location but a hash of the content (see [Content-addressable
RDF](https://openengiadina.net/papers/content-addressable-rdf.html) and
[An Encoding for Robust Immutable Storage](http://purl.org/eris) for
more information). The `/resolve` endpoint can be used to resolve such
content-addressed IRIs.

``` 
GET http://localhost:4000/uri-res/N2R?urn:erisx2:AAAMOKUACTM4OHXSWPIVSZJDAD7C4GE6GR2Y6IPEESIYM7USXKCOGKANY47P3ZR3JBBIWWPKO47CTPJTUZCVLGGTJRXF3Z6G5A2X4GDXEM
Accept: text/turtle
```

``` turtle
@prefix as: <https://www.w3.org/ns/activitystreams#> .
@prefix foaf: <http://xmlns.com/foaf/0.1/> .
@prefix ldp: <http://www.w3.org/ns/ldp#> .
@prefix litepub: <http://litepub.social/ns#> .
@prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
@prefix xsd: <http://www.w3.org/2001/XMLSchema#> .

<urn:erisx2:AAAMOKUACTM4OHXSWPIVSZJDAD7C4GE6GR2Y6IPEESIYM7USXKCOGKANY47P3ZR3JBBIWWPKO47CTPJTUZCVLGGTJRXF3Z6G5A2X4GDXEM>
    a as:Create ;
    as:actor <http://localhost:4000/users/alice> ;
    as:object <urn:erisx2:AAALXO2HYAJZDYZ5NOPNG534NMTQW3DHNCR6QTUJRRWLMO52HU5RSYTF7XQBMXQLHDM6VRHO5Y3H7HO34FOZ4UVVST7H3OGPF2AOFFK724> ;
    as:published "2022-04-23T11:42:58"^^xsd:dateTime ;
    as:to <local:bob> .
```

No authentication is required to access the activity. Simply the fact of
knowing the id (which is not guessable) is enough to gain access.

The created object has not been included in the response, it has an id
of it\'s own and can be accessed directly:

``` 
GET http://localhost:4000/uri-res/N2R?urn:erisx2:AAALXO2HYAJZDYZ5NOPNG534NMTQW3DHNCR6QTUJRRWLMO52HU5RSYTF7XQBMXQLHDM6VRHO5Y3H7HO34FOZ4UVVST7H3OGPF2AOFFK724
Accept: text/turtle
```

``` turtle
@prefix as: <https://www.w3.org/ns/activitystreams#> .
@prefix foaf: <http://xmlns.com/foaf/0.1/> .
@prefix ldp: <http://www.w3.org/ns/ldp#> .
@prefix litepub: <http://litepub.social/ns#> .
@prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
@prefix xsd: <http://www.w3.org/2001/XMLSchema#> .

<urn:erisx2:AAALXO2HYAJZDYZ5NOPNG534NMTQW3DHNCR6QTUJRRWLMO52HU5RSYTF7XQBMXQLHDM6VRHO5Y3H7HO34FOZ4UVVST7H3OGPF2AOFFK724>
    a as:Note ;
    as:attributedTo <http://localhost:4000/users/alice> ;
    as:content "Guten Tag!"@de, "Good day!"@en, "Grüezi"@gsw, "Bun di!"@roh ;
    as:published "2022-04-23T11:42:58"^^xsd:dateTime ;
    as:to <local:bob> .
```

Note that we can also get the object as JSON-LD:

``` 
GET http://localhost:4000/uri-res/N2R?urn:erisx2:AAALXO2HYAJZDYZ5NOPNG534NMTQW3DHNCR6QTUJRRWLMO52HU5RSYTF7XQBMXQLHDM6VRHO5Y3H7HO34FOZ4UVVST7H3OGPF2AOFFK724
```

``` javascript
{
  "@context": [
    "https://www.w3.org/ns/activitystreams#",
    "http://litepub.social/ns#",
    "http://www.w3.org/ns/ldp#"
  ],
  "attributedTo": "http://localhost:4000/users/alice",
  "contentMap": {
    "de": "Guten Tag!",
    "en": "Good day!",
    "gsw": "Grüezi",
    "roh": "Bun di!"
  },
  "id": "urn:erisx2:AAALXO2HYAJZDYZ5NOPNG534NMTQW3DHNCR6QTUJRRWLMO52HU5RSYTF7XQBMXQLHDM6VRHO5Y3H7HO34FOZ4UVVST7H3OGPF2AOFFK724",
  "published": "2022-04-23T11:42:58",
  "to": "local:bob",
  "type": "Note"
}
// GET http://localhost:4000/uri-res/N2R?urn:erisx2:AAALXO2HYAJZDYZ5NOPNG534NMTQW3DHNCR6QTUJRRWLMO52HU5RSYTF7XQBMXQLHDM6VRHO5Y3H7HO34FOZ4UVVST7H3OGPF2AOFFK724
// HTTP/1.1 200 OK
// cache-control: max-age=0, private, must-revalidate
// content-length: 434
// content-type: application/activity+json; charset=utf-8
// date: Sun, 24 Apr 2022 09:29:17 GMT
// server: Cowboy
// x-request-id: FuiVtfdcmjaVaXkAAAhi
// Request duration: 0.213141s
```

The activity is now also in Bob\'s inbox:

``` 
GET http://localhost:4000/users/bob/inbox
Authorization: Bearer GMTHAKCZABOC66AIYEXQV3YAEOFXRSMM37QHKKP6Z2BAYYCH2FNA
```

``` javascript
{
  "@context": [
    "https://www.w3.org/ns/activitystreams#",
    "http://litepub.social/ns#",
    "http://www.w3.org/ns/ldp#"
  ],
  "id": "http://localhost:4000/users/bob/inbox",
  "items": [
    {
      "@context": [
        "https://www.w3.org/ns/activitystreams#",
        "http://litepub.social/ns#",
        "http://www.w3.org/ns/ldp#"
      ],
      "actor": "http://localhost:4000/users/alice",
      "id": "urn:erisx2:AAAMOKUACTM4OHXSWPIVSZJDAD7C4GE6GR2Y6IPEESIYM7USXKCOGKANY47P3ZR3JBBIWWPKO47CTPJTUZCVLGGTJRXF3Z6G5A2X4GDXEM",
      "object": {
        "attributedTo": "http://localhost:4000/users/alice",
        "contentMap": {
          "de": "Guten Tag!",
          "en": "Good day!",
          "gsw": "Grüezi",
          "roh": "Bun di!"
        },
        "id": "urn:erisx2:AAALXO2HYAJZDYZ5NOPNG534NMTQW3DHNCR6QTUJRRWLMO52HU5RSYTF7XQBMXQLHDM6VRHO5Y3H7HO34FOZ4UVVST7H3OGPF2AOFFK724",
        "published": "2022-04-23T11:42:58",
        "to": "local:bob",
        "type": "Note"
      },
      "published": "2022-04-23T11:42:58",
      "to": "local:bob",
      "type": "Create"
    }
  ],
  "member": [
    {
      "@context": [
        "https://www.w3.org/ns/activitystreams#",
        "http://litepub.social/ns#",
        "http://www.w3.org/ns/ldp#"
      ],
      "actor": "http://localhost:4000/users/alice",
      "id": "urn:erisx2:AAAMOKUACTM4OHXSWPIVSZJDAD7C4GE6GR2Y6IPEESIYM7USXKCOGKANY47P3ZR3JBBIWWPKO47CTPJTUZCVLGGTJRXF3Z6G5A2X4GDXEM",
      "object": {
        "attributedTo": "http://localhost:4000/users/alice",
        "contentMap": {
          "de": "Guten Tag!",
          "en": "Good day!",
          "gsw": "Grüezi",
          "roh": "Bun di!"
        },
        "id": "urn:erisx2:AAALXO2HYAJZDYZ5NOPNG534NMTQW3DHNCR6QTUJRRWLMO52HU5RSYTF7XQBMXQLHDM6VRHO5Y3H7HO34FOZ4UVVST7H3OGPF2AOFFK724",
        "published": "2022-04-23T11:42:58",
        "to": "local:bob",
        "type": "Note"
      },
      "published": "2022-04-23T11:42:58",
      "to": "local:bob",
      "type": "Create"
    }
  ],
  "totalItems": "1",
  "type": [
    "BasicContainer",
    "OrderedCollection"
  ]
}
```

## Public addressing

Alice can create a note that should be publicly accessible by addressing
it to the special public collection
(`https://www.w3.org/ns/activitystreams#Public`).

``` 
POST http://localhost:4000/users/alice/outbox
Authorization: Bearer RWGHS3IVQTWLFKACA2NF5BEXZ6AUS7IQHPPC56IVTUFCBBFQ3MPQ
Content-type: text/turtle

@prefix as: <https://www.w3.org/ns/activitystreams#> .

<>
    a as:Create ;
    as:to as:Public ;
    as:object _:object .

_:object
    a as:Note ;
    as:content "Hi! This is a public note." .
```

```
// POST http://localhost:4000/users/alice/outbox
// HTTP/1.1 201 Created
// cache-control: max-age=0, private, must-revalidate
// content-length: 0
// date: Sun, 24 Apr 2022 09:41:52 GMT
// location: http://localhost:4000/uri-res/N2R?urn:erisx2:AAAAWETADJEVBL3YUAKTUBHHAGG3YFTPE2L7CRRHJPHTO4YVQYAC4FLMIG6U6TV5ORTQF5INROYWT6JDEEHA756NAJI3CDOKXES4G25NAE
// server: Cowboy
// x-request-id: FuiWZ19ue63dKX4AAAmC
// Request duration: 0.220309s
```

This activity has been placed in Alice\'s outbox:

``` 
GET http://localhost:4000/users/alice/outbox
Authorization: Bearer RWGHS3IVQTWLFKACA2NF5BEXZ6AUS7IQHPPC56IVTUFCBBFQ3MPQ
Accept: text/turtle
```

``` turtle
@prefix as: <https://www.w3.org/ns/activitystreams#> .
@prefix foaf: <http://xmlns.com/foaf/0.1/> .
@prefix ldp: <http://www.w3.org/ns/ldp#> .
@prefix litepub: <http://litepub.social/ns#> .
@prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
@prefix xsd: <http://www.w3.org/2001/XMLSchema#> .

<http://localhost:4000/users/alice/outbox>
    a ldp:BasicContainer, as:OrderedCollection ;
    ldp:member <urn:erisx2:AAAMOKUACTM4OHXSWPIVSZJDAD7C4GE6GR2Y6IPEESIYM7USXKCOGKANY47P3ZR3JBBIWWPKO47CTPJTUZCVLGGTJRXF3Z6G5A2X4GDXEM>, <urn:erisx2:AAAO6JVQ2EKGCUPRCYROEYYBGZF25SS7BVHU6GEYGKHEJYLVO2TCXAPPEYUMG7SH3KPZTMM5LLKTDDB75ISC6APKDS4NZ2GHTBQ5UVTTCA> ;
    as:items <urn:erisx2:AAAMOKUACTM4OHXSWPIVSZJDAD7C4GE6GR2Y6IPEESIYM7USXKCOGKANY47P3ZR3JBBIWWPKO47CTPJTUZCVLGGTJRXF3Z6G5A2X4GDXEM>, <urn:erisx2:AAAO6JVQ2EKGCUPRCYROEYYBGZF25SS7BVHU6GEYGKHEJYLVO2TCXAPPEYUMG7SH3KPZTMM5LLKTDDB75ISC6APKDS4NZ2GHTBQ5UVTTCA> ;
    as:totalItems "2"^^xsd:nonNegativeInteger .
```

It can also be accessed from the special endpoint for public activities:

``` 
GET http://localhost:4000/public
Accept: text/turtle
```

``` turtle
@prefix as: <https://www.w3.org/ns/activitystreams#> .
@prefix foaf: <http://xmlns.com/foaf/0.1/> .
@prefix ldp: <http://www.w3.org/ns/ldp#> .
@prefix litepub: <http://litepub.social/ns#> .
@prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
@prefix xsd: <http://www.w3.org/2001/XMLSchema#> .

as:Public
    a ldp:BasicContainer, as:OrderedCollection ;
    ldp:member <urn:erisx2:AAAAWETADJEVBL3YUAKTUBHHAGG3YFTPE2L7CRRHJPHTO4YVQYAC4FLMIG6U6TV5ORTQF5INROYWT6JDEEHA756NAJI3CDOKXES4G25NAE> ;
    as:items <urn:erisx2:AAAAWETADJEVBL3YUAKTUBHHAGG3YFTPE2L7CRRHJPHTO4YVQYAC4FLMIG6U6TV5ORTQF5INROYWT6JDEEHA756NAJI3CDOKXES4G25NAE> ;
    as:totalItems "1"^^xsd:nonNegativeInteger .

```

## Generality

CPub has an understanding of what activities are (as defined in
ActivityStreams) and uses this understanding to figure out what to do
when you post something to an outbox.

Other than that, CPub is completely oblivious to what kind of data you
create, share or link to (as long as it is RDF).

### Event

For example we can create an event instead of a note (using the
schema.org vocabulary):

``` 
POST http://localhost:4000/users/alice/outbox
Authorization: Bearer RWGHS3IVQTWLFKACA2NF5BEXZ6AUS7IQHPPC56IVTUFCBBFQ3MPQ
Accept: text/turtle
Content-type: text/turtle

@prefix as: <https://www.w3.org/ns/activitystreams#> .
@prefix schema: <http://schema.org/> .
@prefix xsd: <http://www.w3.org/2001/XMLSchema> .

<>
    a as:Create ;
    as:to <http://localhost:4000/users/bob> ;
    as:object _:object .

_:object
    a schema:Event ;
    schema:name "My super cool event" ;
    schema:url "http://website-to-my-event" ;
    schema:startDate "2020-04-31T00:00:00+01:00"^^xsd:date ;
    schema:endDate "2020-05-02T00:00:00+01:00"^^xsd:date .

```

```
// POST http://localhost:4000/users/alice/outbox
// HTTP/1.1 201 Created
// cache-control: max-age=0, private, must-revalidate
// content-length: 0
// date: Sun, 24 Apr 2022 10:06:23 GMT
// location: http://localhost:4000/uri-res/N2R?urn:erisx2:AAAHEDOI6LFL6WQRTMLDJNBFK5XD65SNC7RIUYIHVBQOYITADS7PYCMWLOQ2Z7JIZTCNOXG2YKLY2LMR3J2HSU6WJ7Z5KULPDFRBBGTLOI
// server: Cowboy
// x-request-id: FuiXwTN32oZi1sUAACSj
// Request duration: 0.222990s
```

The activity:

``` 
GET http://localhost:4000/uri-res/N2R?urn:erisx2:AAAHEDOI6LFL6WQRTMLDJNBFK5XD65SNC7RIUYIHVBQOYITADS7PYCMWLOQ2Z7JIZTCNOXG2YKLY2LMR3J2HSU6WJ7Z5KULPDFRBBGTLOI
Accept: text/turtle
```

``` turtle
@prefix as: <https://www.w3.org/ns/activitystreams#> .
@prefix foaf: <http://xmlns.com/foaf/0.1/> .
@prefix ldp: <http://www.w3.org/ns/ldp#> .
@prefix litepub: <http://litepub.social/ns#> .
@prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
@prefix xsd: <http://www.w3.org/2001/XMLSchema#> .

<urn:erisx2:AAAHEDOI6LFL6WQRTMLDJNBFK5XD65SNC7RIUYIHVBQOYITADS7PYCMWLOQ2Z7JIZTCNOXG2YKLY2LMR3J2HSU6WJ7Z5KULPDFRBBGTLOI>
    a as:Create ;
    as:actor <http://localhost:4000/users/alice> ;
    as:object <urn:erisx2:AAADWQO3SAOX6M4H54E2AFTDSXDOOZZPB42IIQZOEIJB4TP5BTATRGOJKUOVBNDPY6YDAGUPUJF7ECBS3CA5JTXFODATM4YI7JP2MDYLK4> ;
    as:published "2022-04-24T10:06:23"^^xsd:dateTime ;
    as:to <http://localhost:4000/users/bob> .

```

And the event

``` restclient
GET http://localhost:4000/uri-res/N2R?urn:erisx2:AAADWQO3SAOX6M4H54E2AFTDSXDOOZZPB42IIQZOEIJB4TP5BTATRGOJKUOVBNDPY6YDAGUPUJF7ECBS3CA5JTXFODATM4YI7JP2MDYLK4
Accept: text/turtle
```

The event can be commented on, liked or shared, like any other
ActivityPub object.

Note that CPub can also return any object as JSON-LD:

``` restclient
GET http://localhost:4000/uri-res/N2R?urn:erisx2:AAADWQO3SAOX6M4H54E2AFTDSXDOOZZPB42IIQZOEIJB4TP5BTATRGOJKUOVBNDPY6YDAGUPUJF7ECBS3CA5JTXFODATM4YI7JP2MDYLK4
```

Or [RDF/JSON](https://www.w3.org/TR/rdf-json/) (another JSON based
encoding of RDF):

``` restclient
GET http://localhost:4000/uri-res/N2R?urn:erisx2:AAADWQO3SAOX6M4H54E2AFTDSXDOOZZPB42IIQZOEIJB4TP5BTATRGOJKUOVBNDPY6YDAGUPUJF7ECBS3CA5JTXFODATM4YI7JP2MDYLK4
Accept: application/rdf+json
```

### Geo data

It is also possible to post geospatial data. For example a geo-tagged
note:

``` 
POST http://localhost:4000/users/alice/outbox
Authorization: Bearer RS6XZHOA5E5CWWXFXK7THURZ3DBGHT6XBO3QHHJUGOEOTMHLGXMQ
Accept: text/turtle
Content-type: text/turtle

@prefix as: <https://www.w3.org/ns/activitystreams#> .
@prefix geo: <http://www.w3.org/2003/01/geo/wgs84_pos#> .

<>
    a as:Create ;
    as:to <http://localhost:4000/users/bob> ;
    as:object _:object .

_:object
    a as:Note ;
    as:content "The water here is amazing!"@en ;
    geo:lat 46.794932821448725 ;
    geo:long 10.300304889678957 .

```

```
// POST http://localhost:4000/users/alice/outbox
// HTTP/1.1 201 Created
// Location: http://localhost:4000/objects?iri=urn%3Aerisx%3AAAAAADFXIQY4LSBEQ7BBSFKPXO6D2Y7AYJ6ABAD2V4MHGL2USQKH5ZKC2VBATFJLS7JRHFAHTCGE7DSXEXWBPLODKDMOI2TLGPW2BGKX7G4A
// cache-control: max-age=0, private, must-revalidate
// content-length: 0
// date: Mon, 27 Jul 2020 10:03:34 GMT
// server: Cowboy
// x-request-id: FiWS68CX3xx2EY0AAB7h
// Request duration: 0.072037s
```

A geo-tagged note has been created:

``` 
GET http://localhost:4000/objects?iri=urn%3Aerisx%3AAAAAADFXIQY4LSBEQ7BBSFKPXO6D2Y7AYJ6ABAD2V4MHGL2USQKH5ZKC2VBATFJLS7JRHFAHTCGE7DSXEXWBPLODKDMOI2TLGPW2BGKX7G4A
Accept: text/turtle
```

``` turtle
@prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
@prefix xsd: <http://www.w3.org/2001/XMLSchema#> .
@prefix ldp: <http://www.w3.org/ns/ldp#> .
@prefix foaf: <http://xmlns.com/foaf/0.1/> .
@prefix as: <https://www.w3.org/ns/activitystreams#> .

<urn:erisx:AAAAADFXIQY4LSBEQ7BBSFKPXO6D2Y7AYJ6ABAD2V4MHGL2USQKH5ZKC2VBATFJLS7JRHFAHTCGE7DSXEXWBPLODKDMOI2TLGPW2BGKX7G4A>
    a as:Create ;
    as:actor <http://localhost:4000/users/alice> ;
    as:object <urn:erisx:AAAABILVVDOAGFEMM76LEU4LB63RPUG53DEMNGIHWTDZET5EE77KSA36IKYKIBWQ5I3MWRF6L3W3JZS74SLTIBJ2NATKIY4WY5MYY2T2GF6A> ;
    as:to <http://localhost:4000/users/bob> .
```

``` 
GET http://localhost:4000/objects?iri=urn:erisx:AAAABILVVDOAGFEMM76LEU4LB63RPUG53DEMNGIHWTDZET5EE77KSA36IKYKIBWQ5I3MWRF6L3W3JZS74SLTIBJ2NATKIY4WY5MYY2T2GF6A
Accept: text/turtle
```

``` turtle
@prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
@prefix xsd: <http://www.w3.org/2001/XMLSchema#> .
@prefix ldp: <http://www.w3.org/ns/ldp#> .
@prefix foaf: <http://xmlns.com/foaf/0.1/> .
@prefix as: <https://www.w3.org/ns/activitystreams#> .

<urn:erisx:AAAABILVVDOAGFEMM76LEU4LB63RPUG53DEMNGIHWTDZET5EE77KSA36IKYKIBWQ5I3MWRF6L3W3JZS74SLTIBJ2NATKIY4WY5MYY2T2GF6A>
    a as:Note ;
    <http://www.w3.org/2003/01/geo/wgs84_pos#lat> 46.794932821448725 ;
    <http://www.w3.org/2003/01/geo/wgs84_pos#long> 10.300304889678957 ;
    as:content "The water here is amazing!"@en .
```

A client that understands what `geo:lat` and `geo:long` means could show
this note on a map.

See [GeoPub](https://gitlab.com/miaEngiadina/geopub) for a client that
understands `geo:lat` and `geo:long`.

## NodeInfo

CPub supports the
[NodeInfo](https://github.com/jhass/nodeinfo/blob/main/PROTOCOL.md)
protocol:

``` 
GET http://localhost:4000/nodeinfo/2.1
```

``` javascript
{
  "metadata": {},
  "openRegistrations": null,
  "protocols": [
    "activitypub"
  ],
  "services": {
    "inbound": [],
    "outbound": []
  },
  "software": {
    "name": "cpub",
    "repository": "https://gitlab.com/openengiadina/cpub",
    "version": "0.3.0-dev"
  },
  "usage": {
    "users": {
      "total": 0
    }
  },
  "version": "2.1"
}
```

## WebFinger

CPub supports the [WebFinger protocol
(RFC7033)](https://datatracker.ietf.org/doc/html/rfc7033):

``` 
GET http://localhost:4000/.well-known/webfinger?resource=acct:alice@localhost
```

``` javascript
{
  "aliases": [
    "http://localhost:4000/users/alice"
  ],
  "links": [
    {
      "href": "http://localhost:4000/users/alice",
      "rel": "http://webfinger.net/rel/profile-page",
      "type": "text/html"
    },
    {
      "href": "http://localhost:4000/users/alice",
      "rel": "self",
      "type": "application/activity+json"
    },
    {
      "href": "http://localhost:4000/users/alice",
      "rel": "self",
      "type": "application/ld+json; profile=\"https://www.w3.org/ns/activitystreams\""
    }
  ],
  "subject": "acct:alice@localhost"
}
```
