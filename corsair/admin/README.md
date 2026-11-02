# Admin

```
docker network create --driver bridge admin
```

```
sops -d encrypted.arcane.env > arcane.env
sops -d encrypted.beszel.env > beszel.env
docker compose up -d
```
