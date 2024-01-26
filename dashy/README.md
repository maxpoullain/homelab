# Dashy

```
sops -d ./config/conf.encrypted.yml > ./config/conf.yml
sops -d ./config/health.encrypted.yml > ./config/health.yml
docker compose up -d
```
