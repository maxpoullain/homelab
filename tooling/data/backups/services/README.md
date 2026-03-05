# Service Restore Guides

Detailed restore documentation for each homelab service.

## Quick Links

- [Immich](./immich-restore.md) - PostgreSQL database + storage files
- [Vaultwarden](./vaultwarden-restore.md) - SQLite database + RSA keys + attachments
- [Home Assistant](./homeassistant-restore.md) - SQLite database + YAML configs
- [Jellyfin](./jellyfin-restore.md) - Full backup (databases + metadata + plugins)
- [Traefik](./traefik-restore.md) - SSL/TLS certificates
- [Zigbee2mqtt](./zigbee2mqtt-restore.md) - Configuration + database + coordinator backup
- [AdGuard Home](./adguard-restore.md) - Configuration + filters + statistics database
- [Prowlarr](./prowlarr-restore.md) - Full backup (databases + config + definitions)
- [Radarr](./radarr-restore.md) - Full backup (databases + config)
- [Sonarr](./sonarr-restore.md) - Full backup (databases + config)
- [Seerr](./seerr-restore.md) - Full backup (settings + request database)
- [Beszel](./beszel-restore.md) - PocketBase database (users + systems + alert rules)
- [Arcane](./arcane-restore.md) - SQLite database
- [Papra](./papra-restore.md) - SQLite database + documents
- [OctoPrint](./octoprint-restore.md) - Full backup (config + plugins + uploads)

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
