# Traefik

```
docker network create --driver bridge traefik
```

```
sops -d -i statics/core/basicauth.yaml
docker-compose up -d
```