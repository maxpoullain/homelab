# Traefik

```
docker network create --driver bridge traefik
```

```
sops --input-type yaml --output-type yaml -d traefik/config/security/middlewares.yml.encrypted > traefik/config/security/middlewares.yml
#  docker exec crowdsec cscli bouncers add traefik-bouncer -o raw 
sops -d encrypted.env > .env
docker compose up -d
```

## Upgrade CrowSec Hub
```
docker exec crowdsec cscli hub update
docker exec crowdsec cscli hub upgrade
```