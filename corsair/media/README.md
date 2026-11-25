# Media

```
docker network create --driver bridge immich
```

```
sops -d encrypted.env > .env
docker compose up -d
```

## ImmichFrame
```
sops -d immichframe/config/encrypted.Settings.yml > immichframe/config/Settings.yml
docker compose up -d immichframe
```
