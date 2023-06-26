# Traefik

```
docker network create --driver bridge traefik
```

```
sops -d statics/core/basicauth.encrypted.yaml > statics/core/basicauth.yaml
docker-compose up -d
```