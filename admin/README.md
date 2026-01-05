# Admin

```
docker network create --driver bridge admin
```

```
sops -d encrypted.env > .env
docker compose up -d
```