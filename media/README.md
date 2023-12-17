# Media

```
sops -d secrets.encrypted.env > secrets.env
sops --input-type ini --output-type ini -d media/wg0.encrypted.conf > media/wg0.conf
docker compose up -d
```