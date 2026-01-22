# 7 Seas

```
docker network create --driver bridge 7seas
sops -d encrypted.env > .env
sops -d encrypted.env > ygg.env
sops -d pia/encrypted.env > pia/.env
docker compose up -d
```
