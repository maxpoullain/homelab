# Traefik

```
docker network create --driver bridge traefik
```

```
sops --input-type yaml --output-type yaml -d statics/core/basicauth.yaml.encrypted > statics/core/basicauth.yaml
docker compose up -d
```