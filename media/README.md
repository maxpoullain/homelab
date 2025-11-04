# Media

```
docker network create --driver bridge media
touch secrets.env
sops -d pia/encrypted.env > pia/.env
docker compose up -d
```
