<!--
SPDX-FileCopyrightText: 2020 pukkamustard <pukkamustard@posteo.net>

SPDX-License-Identifier: CC-BY-SA-4.0
-->

# Demo

A demo of selected features of CPub.

# Create a User

Users can be created from the Elixir shell.

For example we create the user &ldquo;alice&rdquo; with password &ldquo;123&rdquo;:

    CPub.User.create(%{username: "alice", password: "123"})

This creates the user, an actor profile, inbox and outbox for the user and inserts it into the database in a transaction.

    GET http://localhost:4000/users/alice
    Accept: text/turtle

    @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
    @prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
    @prefix xsd: <http://www.w3.org/2001/XMLSchema#> .
    @prefix ldp: <http://www.w3.org/ns/ldp#> .
    @prefix foaf: <http://xmlns.com/foaf/0.1/> .
    @prefix as: <https://www.w3.org/ns/activitystreams#> .
    
    <http://localhost:4000/users/alice>
        a foaf:PersonalProfileDocument, as:Person ;
        ldp:inbox <http://localhost:4000/users/alice/inbox> ;
        foaf:primaryTopic <http://localhost:4000/users/alice#me> ;
        as:outbox <http://localhost:4000/users/alice/outbox> ;
        as:preferredUsername "alice" .
    
    <http://localhost:4000/users/alice#me>
        a foaf:Person ;
        foaf:name "alice" ;
        foaf:nick "alice" .
    
    // GET http://localhost:4000/users/alice
    // HTTP/1.1 200 OK
    // cache-control: max-age=0, private, must-revalidate
    // content-length: 719
    // content-type: text/turtle; charset=utf-8
    // date: Mon, 27 Jul 2020 09:14:39 GMT
    // server: Cowboy
    // x-request-id: FiWRMFgq_6rl1QQAAAAC
    // Request duration: 0.052300s

An inbox and outbox has been created for the actor. To access the inbox and outbox we first need to authenticate as &ldquo;alice&rdquo; and get a authorization token.


# Authentication and Authorization

All routes that are only accessible to specific users can only be accessed with appropriate authorization.

To get authorization we first need to authenticate as Alice. Once we are authenticated CPub will issue an authorization that we can use to access the protected routes (e.g. inbox and outbox).

CPub uses OAuth 2.0 for managing authorization. It can authenticate users via username and password as well with external identity providers.

We use simple username/password authentication via the OAuth 2.0 &ldquo;Resource Owner Password Credentials&rdquo; flow. This will immediately return us an access<sub>token</sub> that we can use.

For web applications it is more suitable to use the &ldquo;Implicit&rdquo; flow. See the documentation on [Authentication and Authorization](./auth.md) for more information.

    POST http://localhost:4000/oauth/token
    Content-type: application/json
    
    {"grant_type": "password",
     "username": "alice",
     "password": "123"
    }

    {
      "access_token": "RS6XZHOA5E5CWWXFXK7THURZ3DBGHT6XBO3QHHJUGOEOTMHLGXMQ",
      "expires_in": 5184000,
      "refresh_token": "7EVOMDKIFRDILF3LO5MG6GIROZSGNN2I4EH2PLM672AKCESUHAPQ",
      "token_type": "bearer"
    }
    // POST http://localhost:4000/oauth/token
    // HTTP/1.1 200 OK
    // cache-control: max-age=0, private, must-revalidate
    // content-length: 185
    // content-type: application/json; charset=utf-8
    // date: Mon, 27 Jul 2020 09:14:55 GMT
    // server: Cowboy
    // x-request-id: FiWRM-3r9zxCRGsAAAAi
    // Request duration: 0.543683s


# Inbox and Outbox

We can now access Alice&rsquo;s inbox by using the \`access<sub>token</sub>\`:

    GET http://localhost:4000/users/alice/inbox
    Accept: text/turtle
    Authorization: Bearer RS6XZHOA5E5CWWXFXK7THURZ3DBGHT6XBO3QHHJUGOEOTMHLGXMQ

    @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
    @prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
    @prefix xsd: <http://www.w3.org/2001/XMLSchema#> .
    @prefix ldp: <http://www.w3.org/ns/ldp#> .
    @prefix foaf: <http://xmlns.com/foaf/0.1/> .
    @prefix as: <https://www.w3.org/ns/activitystreams#> .
    
    <http://localhost:4000/users/alice/inbox>
        a ldp:BasicContainer, as:Collection .
    
    // GET http://localhost:4000/users/alice/inbox
    // HTTP/1.1 200 OK
    // cache-control: max-age=0, private, must-revalidate
    // content-length: 396
    // content-type: text/turtle; charset=utf-8
    // date: Mon, 27 Jul 2020 09:15:22 GMT
    // server: Cowboy
    // x-request-id: FiWROlkwkG_drosAAABC
    // Request duration: 0.070365s

As well as the outbox:

    GET http://localhost:4000/users/alice/outbox
    Accept: text/turtle
    Authorization: Bearer RS6XZHOA5E5CWWXFXK7THURZ3DBGHT6XBO3QHHJUGOEOTMHLGXMQ

    @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
    @prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
    @prefix xsd: <http://www.w3.org/2001/XMLSchema#> .
    @prefix ldp: <http://www.w3.org/ns/ldp#> .
    @prefix foaf: <http://xmlns.com/foaf/0.1/> .
    @prefix as: <https://www.w3.org/ns/activitystreams#> .
    
    <http://localhost:4000/users/alice/outbox>
        a ldp:BasicContainer, as:Collection .
    
    // GET http://localhost:4000/users/alice/outbox
    // HTTP/1.1 200 OK
    // cache-control: max-age=0, private, must-revalidate
    // content-length: 397
    // content-type: text/turtle; charset=utf-8
    // date: Mon, 27 Jul 2020 09:15:30 GMT
    // server: Cowboy
    // x-request-id: FiWRPFTTHd9p_Z8AAADC
    // Request duration: 0.051186s

Both inbox and outbox are still empty.

Note that the inbox and outbox are both a Linked Data Platform basic containers and ActivityStreams collection.


# Posting an Activity

We create another user `bob`:

    CPub.User.create(%{username: "bob", password: "123"})

And get an access token for Bob:

    POST http://localhost:4000/oauth/token
    Content-type: application/json
    
    {"grant_type": "password",
     "username": "bob",
     "password": "123"
    }

    {
      "access_token": "MSS3KTAPYUKFOZNAKFJDFWRGXISK4HYQ44HR5KWV2Q3VW77K6FNA",
      "expires_in": 5184000,
      "refresh_token": "XS45CEYDZ75UXBF43C42YSQI6HXY4HNHEM7XWU2PMJAKQNOWRCXQ",
      "token_type": "bearer"
    }
    // POST http://localhost:4000/oauth/token
    // HTTP/1.1 200 OK
    // cache-control: max-age=0, private, must-revalidate
    // content-length: 185
    // content-type: application/json; charset=utf-8
    // date: Mon, 27 Jul 2020 09:15:44 GMT
    // server: Cowboy
    // x-request-id: FiWRP2LRbpsNqfIAAADi
    // Request duration: 0.458070s

We can get Bob&rsquo;s inbox:

    GET http://localhost:4000/users/bob/inbox
    Accept: text/turtle
    Authorization: Bearer MSS3KTAPYUKFOZNAKFJDFWRGXISK4HYQ44HR5KWV2Q3VW77K6FNA

    @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
    @prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
    @prefix xsd: <http://www.w3.org/2001/XMLSchema#> .
    @prefix ldp: <http://www.w3.org/ns/ldp#> .
    @prefix foaf: <http://xmlns.com/foaf/0.1/> .
    @prefix as: <https://www.w3.org/ns/activitystreams#> .
    
    <http://localhost:4000/users/bob/inbox>
        a ldp:BasicContainer, as:Collection .
    
    // GET http://localhost:4000/users/bob/inbox
    // HTTP/1.1 200 OK
    // cache-control: max-age=0, private, must-revalidate
    // content-length: 394
    // content-type: text/turtle; charset=utf-8
    // date: Mon, 27 Jul 2020 09:16:03 GMT
    // server: Cowboy
    // x-request-id: FiWRQ_kKkdlc3esAAAEC
    // Request duration: 0.045647s

Also empty. Let&rsquo;s change that.

Alice can post a note to Bob:

    POST http://localhost:4000/users/alice/outbox
    Authorization: Bearer RS6XZHOA5E5CWWXFXK7THURZ3DBGHT6XBO3QHHJUGOEOTMHLGXMQ
    Accept: text/turtle
    Content-type: text/turtle
    
    @prefix as: <https://www.w3.org/ns/activitystreams#> .
    
    <>
        a as:Create ;
        as:to <http://localhost:4000/users/bob> ;
        as:object _:object .
    
    _:object
        a as:Note ;
        as:content "Good day!"@en ;
        as:content "Guten Tag!"@de ;
        as:content "Grüezi"@gsw ;
        as:content "Bun di!"@roh .

    // POST http://localhost:4000/users/alice/outbox
    // HTTP/1.1 201 Created
    // Location: http://localhost:4000/objects?iri=urn%3Aerisx%3AAAAABIXK6O266WQAUEAHTYWJE5ISS32Z7FOGQH5C6TQWWBMDKH2UZVGBUWB3XR24A6ZJNT5ATNHMHFTQH52HOJ3EUZHRLN5VZI6FIE75Y55A
    // cache-control: max-age=0, private, must-revalidate
    // content-length: 0
    // date: Mon, 27 Jul 2020 09:55:03 GMT
    // server: Cowboy
    // x-request-id: FiWSc6RwqRpVb8YAABeB
    // Request duration: 0.040500s

The activity has been created. CPub returns the location of the activity:

    GET http://localhost:4000/objects?iri=urn%3Aerisx%3AAAAABIXK6O266WQAUEAHTYWJE5ISS32Z7FOGQH5C6TQWWBMDKH2UZVGBUWB3XR24A6ZJNT5ATNHMHFTQH52HOJ3EUZHRLN5VZI6FIE75Y55A
    Accept: text/turtle

    @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
    @prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
    @prefix xsd: <http://www.w3.org/2001/XMLSchema#> .
    @prefix ldp: <http://www.w3.org/ns/ldp#> .
    @prefix foaf: <http://xmlns.com/foaf/0.1/> .
    @prefix as: <https://www.w3.org/ns/activitystreams#> .
    
    <urn:erisx:AAAABIXK6O266WQAUEAHTYWJE5ISS32Z7FOGQH5C6TQWWBMDKH2UZVGBUWB3XR24A6ZJNT5ATNHMHFTQH52HOJ3EUZHRLN5VZI6FIE75Y55A>
        a as:Create ;
        as:actor <http://localhost:4000/users/alice> ;
        as:object <urn:erisx:AAAABDTNLMUYMGZ47D5M2LGFMCJTRFM4LCCBWDVT2AXENQ5NGWA37LGA6U5MNI7P4RSQ3ZWEACVDCVRYFN66TEM4LNH2RUMOHONZRN47KO2Q> ;
        as:to <http://localhost:4000/users/bob> .
    
    // GET http://localhost:4000/objects?iri=urn%3Aerisx%3AAAAABIXK6O266WQAUEAHTYWJE5ISS32Z7FOGQH5C6TQWWBMDKH2UZVGBUWB3XR24A6ZJNT5ATNHMHFTQH52HOJ3EUZHRLN5VZI6FIE75Y55A
    // HTTP/1.1 200 OK
    // cache-control: max-age=0, private, must-revalidate
    // content-length: 685
    // content-type: text/turtle; charset=utf-8
    // date: Mon, 27 Jul 2020 09:55:07 GMT
    // server: Cowboy
    // x-request-id: FiWSdI7K5L6nDyAAABeh
    // Request duration: 0.012234s

No authentication is required to access the activity. Simply the fact of knowing the id (which is not guessable) is enough to gain access.

Note that the activity is content-addressed. The URI is not a HTTP location but a hash of the content (see [Content-addressable RDF](https://openengiadina.net/papers/content-addressable-rdf.html) and [An Encoding for Robust Immutable Storage](https://openengiadina.net/papers/eris.html) for more information). The `/objects` endpoint acts like a proxy or resolver for such content-addressed URIs.

The created object has not been included in the response, it has an id of it&rsquo;s own and can be accessed directly:

    GET urn:erisx:AAAABDTNLMUYMGZ47D5M2LGFMCJTRFM4LCCBWDVT2AXENQ5NGWA37LGA6U5MNI7P4RSQ3ZWEACVDCVRYFN66TEM4LNH2RUMOHONZRN47KO2Q
    Accept: text/turtle

    @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
    @prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
    @prefix xsd: <http://www.w3.org/2001/XMLSchema#> .
    @prefix ldp: <http://www.w3.org/ns/ldp#> .
    @prefix foaf: <http://xmlns.com/foaf/0.1/> .
    @prefix as: <https://www.w3.org/ns/activitystreams#> .
    
    <urn:erisx:AAAABDTNLMUYMGZ47D5M2LGFMCJTRFM4LCCBWDVT2AXENQ5NGWA37LGA6U5MNI7P4RSQ3ZWEACVDCVRYFN66TEM4LNH2RUMOHONZRN47KO2Q>
        a as:Note ;
        as:content "Guten Tag!"@de, "Good day!"@en, "Grüezi"@gsw, "Bun di!"@roh .
    
    // GET http://localhost:4000/objects?iri=urn:erisx:AAAABDTNLMUYMGZ47D5M2LGFMCJTRFM4LCCBWDVT2AXENQ5NGWA37LGA6U5MNI7P4RSQ3ZWEACVDCVRYFN66TEM4LNH2RUMOHONZRN47KO2Q
    // HTTP/1.1 200 OK
    // cache-control: max-age=0, private, must-revalidate
    // content-length: 528
    // content-type: text/turtle; charset=utf-8
    // date: Mon, 27 Jul 2020 09:44:22 GMT
    // server: Cowboy
    // x-request-id: FiWR3NUu7eGhAfsAAAVi
    // Request duration: 0.012386s

The activity has also been placed in the Alice&rsquo;s outbox:

    GET http://localhost:4000/users/alice/outbox
    Authorization: Bearer RS6XZHOA5E5CWWXFXK7THURZ3DBGHT6XBO3QHHJUGOEOTMHLGXMQ
    Accept: text/turtle

    @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
    @prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
    @prefix xsd: <http://www.w3.org/2001/XMLSchema#> .
    @prefix ldp: <http://www.w3.org/ns/ldp#> .
    @prefix foaf: <http://xmlns.com/foaf/0.1/> .
    @prefix as: <https://www.w3.org/ns/activitystreams#> .
    
    <http://localhost:4000/users/alice/outbox>
        a ldp:BasicContainer, as:Collection ;
        ldp:member <urn:erisx:AAAABIXK6O266WQAUEAHTYWJE5ISS32Z7FOGQH5C6TQWWBMDKH2UZVGBUWB3XR24A6ZJNT5ATNHMHFTQH52HOJ3EUZHRLN5VZI6FIE75Y55A> ;
        as:items <urn:erisx:AAAABIXK6O266WQAUEAHTYWJE5ISS32Z7FOGQH5C6TQWWBMDKH2UZVGBUWB3XR24A6ZJNT5ATNHMHFTQH52HOJ3EUZHRLN5VZI6FIE75Y55A> .
    
    <urn:erisx:AAAABDTNLMUYMGZ47D5M2LGFMCJTRFM4LCCBWDVT2AXENQ5NGWA37LGA6U5MNI7P4RSQ3ZWEACVDCVRYFN66TEM4LNH2RUMOHONZRN47KO2Q>
        a as:Note ;
        as:content "Guten Tag!"@de, "Good day!"@en, "Grüezi"@gsw, "Bun di!"@roh .
    
    <urn:erisx:AAAABIXK6O266WQAUEAHTYWJE5ISS32Z7FOGQH5C6TQWWBMDKH2UZVGBUWB3XR24A6ZJNT5ATNHMHFTQH52HOJ3EUZHRLN5VZI6FIE75Y55A>
        a as:Create ;
        as:actor <http://localhost:4000/users/alice> ;
        as:object <urn:erisx:AAAABDTNLMUYMGZ47D5M2LGFMCJTRFM4LCCBWDVT2AXENQ5NGWA37LGA6U5MNI7P4RSQ3ZWEACVDCVRYFN66TEM4LNH2RUMOHONZRN47KO2Q> ;
        as:to <http://localhost:4000/users/bob> .
    
    // GET http://localhost:4000/users/alice/outbox
    // HTTP/1.1 200 OK
    // cache-control: max-age=0, private, must-revalidate
    // content-length: 1262
    // content-type: text/turtle; charset=utf-8
    // date: Mon, 27 Jul 2020 09:55:19 GMT
    // server: Cowboy
    // x-request-id: FiWSdzh2EOqYbpIAABfB
    // Request duration: 0.042317s

And in Bob&rsquo;s inbox:

    GET http://localhost:4000/users/bob/inbox
    Authorization: Bearer MSS3KTAPYUKFOZNAKFJDFWRGXISK4HYQ44HR5KWV2Q3VW77K6FNA
    Accept: text/turtle

    @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
    @prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
    @prefix xsd: <http://www.w3.org/2001/XMLSchema#> .
    @prefix ldp: <http://www.w3.org/ns/ldp#> .
    @prefix foaf: <http://xmlns.com/foaf/0.1/> .
    @prefix as: <https://www.w3.org/ns/activitystreams#> .
    
    <http://localhost:4000/users/bob/inbox>
        a ldp:BasicContainer, as:Collection ;
        ldp:member <urn:erisx:AAAABIXK6O266WQAUEAHTYWJE5ISS32Z7FOGQH5C6TQWWBMDKH2UZVGBUWB3XR24A6ZJNT5ATNHMHFTQH52HOJ3EUZHRLN5VZI6FIE75Y55A> ;
        as:items <urn:erisx:AAAABIXK6O266WQAUEAHTYWJE5ISS32Z7FOGQH5C6TQWWBMDKH2UZVGBUWB3XR24A6ZJNT5ATNHMHFTQH52HOJ3EUZHRLN5VZI6FIE75Y55A> .
    
    <urn:erisx:AAAABDTNLMUYMGZ47D5M2LGFMCJTRFM4LCCBWDVT2AXENQ5NGWA37LGA6U5MNI7P4RSQ3ZWEACVDCVRYFN66TEM4LNH2RUMOHONZRN47KO2Q>
        a as:Note ;
        as:content "Guten Tag!"@de, "Good day!"@en, "Grüezi"@gsw, "Bun di!"@roh .
    
    <urn:erisx:AAAABIXK6O266WQAUEAHTYWJE5ISS32Z7FOGQH5C6TQWWBMDKH2UZVGBUWB3XR24A6ZJNT5ATNHMHFTQH52HOJ3EUZHRLN5VZI6FIE75Y55A>
        a as:Create ;
        as:actor <http://localhost:4000/users/alice> ;
        as:object <urn:erisx:AAAABDTNLMUYMGZ47D5M2LGFMCJTRFM4LCCBWDVT2AXENQ5NGWA37LGA6U5MNI7P4RSQ3ZWEACVDCVRYFN66TEM4LNH2RUMOHONZRN47KO2Q> ;
        as:to <http://localhost:4000/users/bob> .
    
    // GET http://localhost:4000/users/bob/inbox
    // HTTP/1.1 200 OK
    // cache-control: max-age=0, private, must-revalidate
    // content-length: 1259
    // content-type: text/turtle; charset=utf-8
    // date: Mon, 27 Jul 2020 09:55:24 GMT
    // server: Cowboy
    // x-request-id: FiWSeIhm9PENeEsAABfh
    // Request duration: 0.057773s


# Public addressing

Alice can create a note that should be publicly accessible by addressing it to the special public collection (`https://www.w3.org/ns/activitystreams#Public`).

    POST http://localhost:4000/users/alice/outbox
    Authorization: Bearer RS6XZHOA5E5CWWXFXK7THURZ3DBGHT6XBO3QHHJUGOEOTMHLGXMQ
    Accept: text/turtle
    Content-type: text/turtle
    
    @prefix as: <https://www.w3.org/ns/activitystreams#> .
    
    <>
        a as:Create ;
        as:to as:Public ;
        as:object _:object .
    
    _:object
        a as:Note ;
        as:content "Hi! This is a public note." .

    // POST http://localhost:4000/users/alice/outbox
    // HTTP/1.1 201 Created
    // Location: http://localhost:4000/objects?iri=urn%3Aerisx%3AAAAABEB6W7PGNETW6HQ36XR5HT736RZNS4JFDLCZN7K42JGIC5HOT4L2WLQHLY2JUOIHJKDPL45NATIIQY2PQJUA7WQUJUN7JQ7ES3EDN6GA
    // cache-control: max-age=0, private, must-revalidate
    // content-length: 0
    // date: Mon, 27 Jul 2020 09:58:36 GMT
    // server: Cowboy
    // x-request-id: FiWSpYgQC6dWD9gAABlB
    // Request duration: 0.056130s

This activity has been placed in Alice&rsquo;s outbox:

    GET http://localhost:4000/users/alice/outbox
    Authorization: Bearer RS6XZHOA5E5CWWXFXK7THURZ3DBGHT6XBO3QHHJUGOEOTMHLGXMQ
    Accept: text/turtle

    @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
    @prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
    @prefix xsd: <http://www.w3.org/2001/XMLSchema#> .
    @prefix ldp: <http://www.w3.org/ns/ldp#> .
    @prefix foaf: <http://xmlns.com/foaf/0.1/> .
    @prefix as: <https://www.w3.org/ns/activitystreams#> .
    
    <http://localhost:4000/users/alice/outbox>
        a ldp:BasicContainer, as:Collection ;
        ldp:member <urn:erisx:AAAABEB6W7PGNETW6HQ36XR5HT736RZNS4JFDLCZN7K42JGIC5HOT4L2WLQHLY2JUOIHJKDPL45NATIIQY2PQJUA7WQUJUN7JQ7ES3EDN6GA> ;
        as:items <urn:erisx:AAAABEB6W7PGNETW6HQ36XR5HT736RZNS4JFDLCZN7K42JGIC5HOT4L2WLQHLY2JUOIHJKDPL45NATIIQY2PQJUA7WQUJUN7JQ7ES3EDN6GA> .
    
    <urn:erisx:AAAAAX3CRD27X2GTBX7ILUBK4QX2MHH57KQSQEWWG3NO7X4A5PSS6NISE4LRWEEFJDA6SLJTKFFS2KUPY2M5FXOHWGW2WRGUCBWLVT6WZZ4Q>
        a as:Note ;
        as:content "Hi! This is a public note." .
    
    <urn:erisx:AAAABEB6W7PGNETW6HQ36XR5HT736RZNS4JFDLCZN7K42JGIC5HOT4L2WLQHLY2JUOIHJKDPL45NATIIQY2PQJUA7WQUJUN7JQ7ES3EDN6GA>
        a as:Create ;
        as:actor <http://localhost:4000/users/alice> ;
        as:object <urn:erisx:AAAAAX3CRD27X2GTBX7ILUBK4QX2MHH57KQSQEWWG3NO7X4A5PSS6NISE4LRWEEFJDA6SLJTKFFS2KUPY2M5FXOHWGW2WRGUCBWLVT6WZZ4Q> ;
        as:to as:Public .
    
    // GET http://localhost:4000/users/alice/outbox
    // HTTP/1.1 200 OK
    // cache-control: max-age=0, private, must-revalidate
    // content-length: 1205
    // content-type: text/turtle; charset=utf-8
    // date: Mon, 27 Jul 2020 09:58:46 GMT
    // server: Cowboy
    // x-request-id: FiWSp_eQWrsrNeMAABTC
    // Request duration: 0.052612s

It can also be accessed from the special endpoint for public activities:

    GET http://localhost:4000/public
    Accept: text/turtle

    @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
    @prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
    @prefix xsd: <http://www.w3.org/2001/XMLSchema#> .
    @prefix ldp: <http://www.w3.org/ns/ldp#> .
    @prefix foaf: <http://xmlns.com/foaf/0.1/> .
    @prefix as: <https://www.w3.org/ns/activitystreams#> .
    
    as:Public
        a ldp:BasicContainer, as:Collection ;
        ldp:member <urn:erisx:AAAABEB6W7PGNETW6HQ36XR5HT736RZNS4JFDLCZN7K42JGIC5HOT4L2WLQHLY2JUOIHJKDPL45NATIIQY2PQJUA7WQUJUN7JQ7ES3EDN6GA> ;
        as:items <urn:erisx:AAAABEB6W7PGNETW6HQ36XR5HT736RZNS4JFDLCZN7K42JGIC5HOT4L2WLQHLY2JUOIHJKDPL45NATIIQY2PQJUA7WQUJUN7JQ7ES3EDN6GA> .
    
    <urn:erisx:AAAAAX3CRD27X2GTBX7ILUBK4QX2MHH57KQSQEWWG3NO7X4A5PSS6NISE4LRWEEFJDA6SLJTKFFS2KUPY2M5FXOHWGW2WRGUCBWLVT6WZZ4Q>
        a as:Note ;
        as:content "Hi! This is a public note." .
    
    <urn:erisx:AAAABEB6W7PGNETW6HQ36XR5HT736RZNS4JFDLCZN7K42JGIC5HOT4L2WLQHLY2JUOIHJKDPL45NATIIQY2PQJUA7WQUJUN7JQ7ES3EDN6GA>
        a as:Create ;
        as:actor <http://localhost:4000/users/alice> ;
        as:object <urn:erisx:AAAAAX3CRD27X2GTBX7ILUBK4QX2MHH57KQSQEWWG3NO7X4A5PSS6NISE4LRWEEFJDA6SLJTKFFS2KUPY2M5FXOHWGW2WRGUCBWLVT6WZZ4Q> ;
        as:to as:Public .
    
    // GET http://localhost:4000/public
    // HTTP/1.1 200 OK
    // cache-control: max-age=0, private, must-revalidate
    // content-length: 1172
    // content-type: text/turtle; charset=utf-8
    // date: Mon, 27 Jul 2020 10:00:24 GMT
    // server: Cowboy
    // x-request-id: FiWSvy8HAmNfr7wAABlk
    // Request duration: 0.477107s


# Generality

CPub has an understanding of what activities are (as defined in ActivityStreams) and uses this understanding to figure out what to do when you post something to an outbox.

Other than that, CPub is completely oblivious to what kind of data you create, share or link to (as long as it is RDF).


## Event

For example we can create an event instead of a note (using the schema.org vocabulary):

    POST http://localhost:4000/users/alice/outbox
    Authorization: Bearer RS6XZHOA5E5CWWXFXK7THURZ3DBGHT6XBO3QHHJUGOEOTMHLGXMQ
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

    // POST http://localhost:4000/users/alice/outbox
    // HTTP/1.1 201 Created
    // Location: http://localhost:4000/objects?iri=urn%3Aerisx%3AAAAAAZQTUAUZ3TFD72O4GZBOZPDWGL7U3MJ6NGLPHUV6UJUOJHIYBOATPDPE4GJJAR6HPUGPBSBEFQATY5FN6JBU4WAUZYZ5GAO6JZEOKTMQ
    // cache-control: max-age=0, private, must-revalidate
    // content-length: 0
    // date: Mon, 27 Jul 2020 10:01:10 GMT
    // server: Cowboy
    // x-request-id: FiWSyek0P7vsgzYAAByi
    // Request duration: 0.044583s

The activity:

    GET http://localhost:4000/objects?iri=urn%3Aerisx%3AAAAAAZQTUAUZ3TFD72O4GZBOZPDWGL7U3MJ6NGLPHUV6UJUOJHIYBOATPDPE4GJJAR6HPUGPBSBEFQATY5FN6JBU4WAUZYZ5GAO6JZEOKTMQ
    Accept: text/turtle

    @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
    @prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
    @prefix xsd: <http://www.w3.org/2001/XMLSchema#> .
    @prefix ldp: <http://www.w3.org/ns/ldp#> .
    @prefix foaf: <http://xmlns.com/foaf/0.1/> .
    @prefix as: <https://www.w3.org/ns/activitystreams#> .
    
    <urn:erisx:AAAAAZQTUAUZ3TFD72O4GZBOZPDWGL7U3MJ6NGLPHUV6UJUOJHIYBOATPDPE4GJJAR6HPUGPBSBEFQATY5FN6JBU4WAUZYZ5GAO6JZEOKTMQ>
        a as:Create ;
        as:actor <http://localhost:4000/users/alice> ;
        as:object <urn:erisx:AAAABZSRNIW5KYSVZN54JUIKR3V35BMU4DXZPFZFGQA4ZBTVQQLOMJRP2A4ICMRUSKKHGGE44JN7MDHNFDDBX3AEC2QO4CCKEGKN67JBWYOQ> ;
        as:to <http://localhost:4000/users/bob> .
    
    // GET http://localhost:4000/objects?iri=urn%3Aerisx%3AAAAAAZQTUAUZ3TFD72O4GZBOZPDWGL7U3MJ6NGLPHUV6UJUOJHIYBOATPDPE4GJJAR6HPUGPBSBEFQATY5FN6JBU4WAUZYZ5GAO6JZEOKTMQ
    // HTTP/1.1 200 OK
    // cache-control: max-age=0, private, must-revalidate
    // content-length: 685
    // content-type: text/turtle; charset=utf-8
    // date: Mon, 27 Jul 2020 10:01:27 GMT
    // server: Cowboy
    // x-request-id: FiWSzbYU-1XqS8oAAB6B
    // Request duration: 0.016299s

And the event

    GET http://localhost:4000/objects?iri=urn:erisx:AAAABZSRNIW5KYSVZN54JUIKR3V35BMU4DXZPFZFGQA4ZBTVQQLOMJRP2A4ICMRUSKKHGGE44JN7MDHNFDDBX3AEC2QO4CCKEGKN67JBWYOQ
    Accept: text/turtle

The event can be commented on, liked or shared, like any other ActivityPub object.


## Geo data

It is also possible to post geospatial data. For example a geo-tagged note:

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

    // POST http://localhost:4000/users/alice/outbox
    // HTTP/1.1 201 Created
    // Location: http://localhost:4000/objects?iri=urn%3Aerisx%3AAAAAADFXIQY4LSBEQ7BBSFKPXO6D2Y7AYJ6ABAD2V4MHGL2USQKH5ZKC2VBATFJLS7JRHFAHTCGE7DSXEXWBPLODKDMOI2TLGPW2BGKX7G4A
    // cache-control: max-age=0, private, must-revalidate
    // content-length: 0
    // date: Mon, 27 Jul 2020 10:03:34 GMT
    // server: Cowboy
    // x-request-id: FiWS68CX3xx2EY0AAB7h
    // Request duration: 0.072037s

A geo-tagged note has been created:

    GET http://localhost:4000/objects?iri=urn%3Aerisx%3AAAAAADFXIQY4LSBEQ7BBSFKPXO6D2Y7AYJ6ABAD2V4MHGL2USQKH5ZKC2VBATFJLS7JRHFAHTCGE7DSXEXWBPLODKDMOI2TLGPW2BGKX7G4A
    Accept: text/turtle

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
    
    // GET http://localhost:4000/objects?iri=urn%3Aerisx%3AAAAAADFXIQY4LSBEQ7BBSFKPXO6D2Y7AYJ6ABAD2V4MHGL2USQKH5ZKC2VBATFJLS7JRHFAHTCGE7DSXEXWBPLODKDMOI2TLGPW2BGKX7G4A
    // HTTP/1.1 200 OK
    // cache-control: max-age=0, private, must-revalidate
    // content-length: 685
    // content-type: text/turtle; charset=utf-8
    // date: Mon, 27 Jul 2020 10:03:52 GMT
    // server: Cowboy
    // x-request-id: FiWS7_FGi1eKdCIAAB8B
    // Request duration: 0.011451s

    GET http://localhost:4000/objects?iri=urn:erisx:AAAABILVVDOAGFEMM76LEU4LB63RPUG53DEMNGIHWTDZET5EE77KSA36IKYKIBWQ5I3MWRF6L3W3JZS74SLTIBJ2NATKIY4WY5MYY2T2GF6A
    Accept: text/turtle

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
    
    // GET http://localhost:4000/objects?iri=urn:erisx:AAAABILVVDOAGFEMM76LEU4LB63RPUG53DEMNGIHWTDZET5EE77KSA36IKYKIBWQ5I3MWRF6L3W3JZS74SLTIBJ2NATKIY4WY5MYY2T2GF6A
    // HTTP/1.1 200 OK
    // cache-control: max-age=0, private, must-revalidate
    // content-length: 641
    // content-type: text/turtle; charset=utf-8
    // date: Mon, 27 Jul 2020 10:04:46 GMT
    // server: Cowboy
    // x-request-id: FiWS_KG3uMIW4VoAAB9B
    // Request duration: 0.018176s

A client that understands what `geo:lat` and `geo:long` means could show this note on a map.

See [GeoPub](https://gitlab.com/miaEngiadina/geopub) for a client that understands `geo:lat` and `geo:long`.


# Serialization Formats

In the examples above we have used the RDF/Turtle serialization.

CPub supports following RDF serialization formats:

-   [RDF 1.1 Turtle](https://www.w3.org/TR/turtle/)
-   [RDF 1.1 JSON Alternate Serialization (RDF/JSON)](https://www.w3.org/TR/rdf-json/)


## RDF/JSON

To get content as RDF/JSON set the `Accept` header to `application/rdf+json`

    GET http://localhost:4000/users/alice
    Accept: application/rdf+json

    {
      "http://localhost:4000/users/alice": {
        "http://www.w3.org/1999/02/22-rdf-syntax-ns#type": [
          {
            "type": "uri",
            "value": "http://xmlns.com/foaf/0.1/PersonalProfileDocument"
          },
          {
            "type": "uri",
            "value": "https://www.w3.org/ns/activitystreams#Person"
          }
        ],
        "http://www.w3.org/ns/ldp#inbox": [
          {
            "type": "uri",
            "value": "http://localhost:4000/users/alice/inbox"
          }
        ],
        "http://xmlns.com/foaf/0.1/primaryTopic": [
          {
            "type": "uri",
            "value": "http://localhost:4000/users/alice#me"
          }
        ],
        "https://www.w3.org/ns/activitystreams#outbox": [
          {
            "type": "uri",
            "value": "http://localhost:4000/users/alice/outbox"
          }
        ],
        "https://www.w3.org/ns/activitystreams#preferredUsername": [
          {
            "type": "literal",
            "value": "alice"
          }
        ]
      },
      "http://localhost:4000/users/alice#me": {
        "http://www.w3.org/1999/02/22-rdf-syntax-ns#type": [
          {
            "type": "uri",
            "value": "http://xmlns.com/foaf/0.1/Person"
          }
        ],
        "http://xmlns.com/foaf/0.1/name": [
          {
            "type": "literal",
            "value": "alice"
          }
        ],
        "http://xmlns.com/foaf/0.1/nick": [
          {
            "type": "literal",
            "value": "alice"
          }
        ]
      }
    }
    // GET http://localhost:4000/users/alice
    // HTTP/1.1 200 OK
    // cache-control: max-age=0, private, must-revalidate
    // content-length: 942
    // content-type: application/rdf+json; charset=utf-8
    // date: Mon, 27 Jul 2020 10:05:07 GMT
    // server: Cowboy
    // x-request-id: FiWTAZe1DZtR3b4AAB9h
    // Request duration: 0.036612s

Data can also be posted as RDF/JSON by setting `Content-type` header:

    POST http://localhost:4000/users/alice/outbox
    Authorization: Bearer RS6XZHOA5E5CWWXFXK7THURZ3DBGHT6XBO3QHHJUGOEOTMHLGXMQ
    Content-type: application/rdf+json
    
    {
      "_:object": {
        "http://www.w3.org/1999/02/22-rdf-syntax-ns#type": [
          {
            "type": "uri",
            "value": "https://www.w3.org/ns/activitystreams#Note"
          }
        ],
        "https://www.w3.org/ns/activitystreams#content": [
          {
            "lang": "en",
            "type": "literal",
            "value": "Hi! This is RDF/JSON. It's ugly, but it's simple."
          }
        ]
      },
      "http://example.org": {
        "http://www.w3.org/1999/02/22-rdf-syntax-ns#type": [
          {
            "type": "uri",
            "value": "https://www.w3.org/ns/activitystreams#Create"
          }
        ],
        "https://www.w3.org/ns/activitystreams#object": [
          {
            "type": "bnode",
            "value": "_:object"
          }
        ],
        "https://www.w3.org/ns/activitystreams#to": [
          {
            "type": "uri",
            "value": "http://localhost:4000/users/bob"
          }
        ]
      }
    }

    // POST http://localhost:4000/users/alice/outbox
    // HTTP/1.1 201 Created
    // cache-control: max-age=0, private, must-revalidate
    // content-length: 0
    // date: Mon, 27 Jul 2020 10:29:24 GMT
    // location: http://localhost:4000/objects?iri=urn%3Aerisx%3AAAAAB2UI566HXP3ZTEOTN7WLHZZFMKTAZEMV3ZWN6GCCJ7T53H2QVJKNPULT7OPMGZTDOEIORQNEME3UWGRKVNWW2WZQDFSMB4JKZI3KVTPA
    // server: Cowboy
    // x-request-id: FiWUV_M6dqt5o30AABuj
    // Request duration: 0.368228s

