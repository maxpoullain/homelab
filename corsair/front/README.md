# Traefik

```
docker network create --driver bridge traefik
```

```
#  docker exec crowdsec cscli bouncers add traefik-bouncer -o raw 
sops -d encrypted.traefik.env > traefik.env
sops -d encrypted.tinyauth.env > tinyauth.env
sops -d traefik/secrets/encrypted.middlewares.yml > traefik/config/security/middlewares.yml
docker compose up -d
```

> Keep `encrypted.middlewares.yml` in `traefik/secrets/`, never under `traefik/config/`:
> Traefik's file provider loads every `.yml` there, and the ciphertext breaks all routers
> using the `security`/`security-soft` chains.
> Re-encrypt after edits: `sops -e traefik/config/security/middlewares.yml > traefik/secrets/encrypted.middlewares.yml`

## Upgrade CrowSec Hub
```
docker exec crowdsec cscli hub update
docker exec crowdsec cscli hub upgrade
```
