# Traefik

```
docker network create --driver bridge traefik
```

```
sops --input-type yaml --output-type yaml -d config/security/middlewares.yaml.encrypted > config/security/middlewares.yaml
#  docker exec crowdsec cscli bouncers add traefik-plugin -o raw 
sops --input-type yaml --output-type yaml -d config/security/basicauth.yaml.encrypted > config/security/basicauth.yaml
sops -d encrypted.env > .env
docker compose up -d
```