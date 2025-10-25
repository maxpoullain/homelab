# Service Restore Guides

Detailed restore documentation for each homelab service.

## Quick Links

- [Immich](./immich.md) - PostgreSQL database + storage files
- [Vaultwarden](./vaultwarden.md) - SQLite database + RSA keys + attachments
- [OtterWiki](./wiki.md) - SQLite database
- [Home Assistant](./homeassistant.md) - SQLite databases + YAML configs
- [Jellyfin](./jellyfin.md) - Full backup (databases + metadata + plugins)
- [Tailscale](./tailscale.md) - State files
- [Traefik](./traefik.md) - SSL/TLS certificates

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
