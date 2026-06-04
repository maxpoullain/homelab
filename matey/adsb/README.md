# ADS-B

```
docker network create --driver bridge adsb
```
```
sops -d encrypted.env > .env
docker compose up -d
```

## Guide
[https://sdr-enthusiasts.gitbook.io/ads-b](https://sdr-enthusiasts.gitbook.io/ads-b)
