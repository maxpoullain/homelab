# Traefik

```
sops -d -i statics/core/basicauth.yaml
sops -d -i acme/acme.json
chmod 600 acme.json
docker-compose up -d
```