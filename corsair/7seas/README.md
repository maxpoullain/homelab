# 7 Seas

```
docker network create --driver bridge 7seas
sops -d gluetun/encrypted.env > gluetun/.env
docker compose up -d
```
