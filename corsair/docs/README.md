# Docs

```
docker network create --driver bridge bookstack
```

```
sops -d encrypted.bookstack.env > bookstack.env
sops -d encrypted.papra.env > papra.env
docker compose up -d
```
