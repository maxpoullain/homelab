# 7 Seas

```
docker network create --driver bridge 7seas
sops -d gluetun/encrypted.env > gluetun/.env
sops -d cross-seed/encrypted.env > cross-seed/.env
docker compose up -d
```
