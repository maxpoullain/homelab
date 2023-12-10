# Photoprism

```
docker network create --driver bridge photoprism
```

```
sops -d secrets.encrypted.env > secrets.env
docker-compose up -d
```