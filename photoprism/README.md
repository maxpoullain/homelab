# Photoprism

```
docker network create --driver bridge photoprism
```

```
sops -d -i secrets.env
docker-compose up -d
```