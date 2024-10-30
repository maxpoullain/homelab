# Media

```
sops -d secrets.encrypted.env > secrets.env
sops --input-type ini --output-type ini -d media/wireguard/wg0.encrypted.conf > media/wireguard/wg0.conf
docker compose up -d
```
