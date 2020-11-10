# Deployment of CPub

Some notes on how to deploy a CPub instance.

## Nginx

Currently it is required to use use a reverse proxy such as Nginx when exposing CPub to a network.

The `X-Forwarded-*` headers need to be set so that CPub can know from where requests come.

To redirect all traffic to CPub:

```
location / {
    proxy_pass http://localhost:4000/;
    
    proxy_set_header X-Forwarded-Host $host;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header X-Forwarded-Port $server_port;
    proxy_set_header X-Forwarded-For $remote_addr;
}
```

Alternatively individual endpoints may be forwarded allowing other content to be hosted along-side CPub:


```
location /users/ {
    proxy_pass http://localhost:4000/users/;

    proxy_set_header X-Forwarded-Host $host;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header X-Forwarded-Port $server_port;
    proxy_set_header X-Forwarded-For $remote_addr;
}
location /public {
    proxy_pass http://localhost:4000/public;

    proxy_set_header X-Forwarded-Host $host;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header X-Forwarded-Port $server_port;
    proxy_set_header X-Forwarded-For $remote_addr;
}
location /objects/ {
    proxy_pass http://localhost:4000/objects/;

    proxy_set_header X-Forwarded-Host $host;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header X-Forwarded-Port $server_port;
    proxy_set_header X-Forwarded-For $remote_addr;
}
location /auth/ {
    proxy_pass http://localhost:4000/auth/;

    proxy_set_header X-Forwarded-Host $host;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header X-Forwarded-Port $server_port;
    proxy_set_header X-Forwarded-For $remote_addr;
}
location /oauth/ {
    proxy_pass http://localhost:4000/oauth/;

    proxy_set_header X-Forwarded-Host $host;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header X-Forwarded-Port $server_port;
    proxy_set_header X-Forwarded-For $remote_addr;
}
```
