# MailFlow

```
docker network create --driver bridge mailflow
```

```
sops -d encrypted.env > .env
docker compose up -d
```
