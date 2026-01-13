# Service Restore Guides

Detailed restore documentation for each homelab service.

## Quick Links

- [Immich](./immich-restore.md) - PostgreSQL database + storage files
- [Vaultwarden](./vaultwarden-restore.md) - SQLite database + RSA keys + attachments
- [Home Assistant](./homeassistant-restore.md) - SQLite databases + YAML configs
- [Jellyfin](./jellyfin-restore.md) - Full backup (databases + metadata + plugins)
- [Tailscale](./tailscale-restore.md) - State files
- [Traefik](./traefik-restore.md) - SSL/TLS certificates
- [Zigbee2mqtt](./zigbee2mqtt-restore.md) - Configuration + database + coordinator backup
- [AdGuard Home](./adguard-restore.md) - Configuration + filters + statistics database
- [Mosquitto](./mosquitto-restore.md) - MQTT config
- [Prowlarr](./prowlarr-restore.md) - Full backup (databases + config + definitions)
- [Radarr](./radarr-restore.md) - Full backup (databases + config)
- [Readarr](./readarr-restore.md) - Full backup (databases + config)
- [Sonarr](./sonarr-restore.md) - Full backup (databases + config)

## Backup Location

All backups are stored in: `/mnt/tank/backups/homelab/[service]/`

## General Restore Pattern

Most services follow this pattern:

1. Stop the service
2. Restore backup files
3. Fix permissions
4. Start the service
5. Verify functionality

See individual service guides for specific instructions.
