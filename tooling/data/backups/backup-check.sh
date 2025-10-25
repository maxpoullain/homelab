#!/bin/bash

echo "=== Homelab Services Backup Status ==="
echo ""

# Check if backup script is in crontab (system or TrueNAS)
echo "Cron job status:"
CRON_FOUND=false

# Check system crontab
if sudo crontab -l 2>/dev/null | grep -q "backup-services.sh"; then
  echo "  ✓ System crontab: Backup job is configured"
  sudo crontab -l | grep "backup-services.sh"
  CRON_FOUND=true
fi

# Check TrueNAS cron jobs (stored in middleware database)
if command -v midclt &> /dev/null; then
  if midclt call cronjob.query 2>/dev/null | grep -q "backup-services.sh"; then
    echo "  ✓ TrueNAS cron: Backup job is configured"
    midclt call cronjob.query 2>/dev/null | grep -A 10 "backup-services.sh" | head -15
    CRON_FOUND=true
  fi
fi

# Check /etc/cron.d/ for TrueNAS managed crons
if [ -d "/etc/cron.d" ]; then
  if grep -r "backup-services.sh" /etc/cron.d/ 2>/dev/null; then
    echo "  ✓ TrueNAS /etc/cron.d/: Backup job is configured"
    grep -r "backup-services.sh" /etc/cron.d/ 2>/dev/null
    CRON_FOUND=true
  fi
fi

if [ "$CRON_FOUND" = false ]; then
  echo "  ✗ Backup cron job NOT found"
  echo "  → Set up via TrueNAS GUI: Tasks → Cron Jobs → Add"
  echo "  → Command: /mnt/fast/apps/homelab/tooling/data/backups/backup-services.sh"
  echo "  → Schedule: 0 7,19 * * * (7 AM and 7 PM daily)"
fi
echo ""

# Check if containers are running
echo "Container status:"
echo -n "  Immich Postgres: "
docker ps --format "{{.Names}}" | grep -q immich_postgres && echo "✓ Running" || echo "✗ Not running"
echo -n "  Vaultwarden: "
docker ps --format "{{.Names}}" | grep -q vaultwarden && echo "✓ Running" || echo "✗ Not running"
echo -n "  OtterWiki: "
docker ps --format "{{.Names}}" | grep -q otterwiki && echo "✓ Running" || echo "✗ Not running"
echo -n "  Home Assistant: "
docker ps --format "{{.Names}}" | grep -q "^ha$" && echo "✓ Running" || echo "✗ Not running"
echo -n "  Jellyfin: "
docker ps --format "{{.Names}}" | grep -q jellyfin && echo "✓ Running" || echo "✗ Not running"
echo -n "  Tailscale: "
docker ps --format "{{.Names}}" | grep -q tailscale && echo "✓ Running" || echo "✗ Not running"
echo -n "  Traefik: "
docker ps --format "{{.Names}}" | grep -q traefik && echo "✓ Running" || echo "✗ Not running"
echo ""

# Check last backup time
echo "Last backup times:"
IMMICH_LAST=$(ls -lt /mnt/tank/backups/homelab/immich/db-*.sql.gz 2>/dev/null | head -1 | awk '{print $6, $7, $8, $9}')
VAULT_LAST=$(ls -lt /mnt/tank/backups/homelab/vaultwarden/db-*.sqlite3 2>/dev/null | head -1 | awk '{print $6, $7, $8, $9}')
WIKI_LAST=$(ls -lt /mnt/tank/backups/homelab/wiki/db-*.sqlite3 2>/dev/null | head -1 | awk '{print $6, $7, $8, $9}')
HA_LAST=$(ls -lt /mnt/tank/backups/homelab/homeassistant/db-*.sqlite3 2>/dev/null | head -1 | awk '{print $6, $7, $8, $9}')
JELLYFIN_LAST=$(ls -lt /mnt/tank/backups/homelab/jellyfin/full-*.tar.gz 2>/dev/null | head -1 | awk '{print $6, $7, $8, $9}')
TAILSCALE_LAST=$(ls -lt /mnt/tank/backups/homelab/tailscale/state-*.tar.gz 2>/dev/null | head -1 | awk '{print $6, $7, $8, $9}')
TRAEFIK_LAST=$(ls -lt /mnt/tank/backups/homelab/traefik/acme-*.tar.gz 2>/dev/null | head -1 | awk '{print $6, $7, $8, $9}')

echo "  Immich:          ${IMMICH_LAST:-No backups found}"
echo "  Vaultwarden:     ${VAULT_LAST:-No backups found}"
echo "  OtterWiki:       ${WIKI_LAST:-No backups found}"
echo "  Home Assistant:  ${HA_LAST:-No backups found}"
echo "  Jellyfin:        ${JELLYFIN_LAST:-No backups found}"
echo "  Tailscale:       ${TAILSCALE_LAST:-No backups found}"
echo "  Traefik:         ${TRAEFIK_LAST:-No backups found}"
echo ""

# Check backup counts
echo "Backup file counts:"
IMMICH_DB_COUNT=$(ls -1 /mnt/tank/backups/homelab/immich/db-*.sql.gz 2>/dev/null | wc -l)
IMMICH_STORAGE_COUNT=$(ls -1 /mnt/tank/backups/homelab/immich/storage-*.tar.gz 2>/dev/null | wc -l)
VAULT_DB_COUNT=$(ls -1 /mnt/tank/backups/homelab/vaultwarden/db-*.sqlite3 2>/dev/null | wc -l)
VAULT_RSA_COUNT=$(ls -1 /mnt/tank/backups/homelab/vaultwarden/rsa_key-*.pem 2>/dev/null | wc -l)
VAULT_ATT_COUNT=$(ls -1 /mnt/tank/backups/homelab/vaultwarden/attachments-*.tar.gz 2>/dev/null | wc -l)
WIKI_COUNT=$(ls -1 /mnt/tank/backups/homelab/wiki/db-*.sqlite3 2>/dev/null | wc -l)
HA_DB_COUNT=$(ls -1 /mnt/tank/backups/homelab/homeassistant/db-*.sqlite3 2>/dev/null | wc -l)
HA_ZIGBEE_COUNT=$(ls -1 /mnt/tank/backups/homelab/homeassistant/zigbee-*.sqlite3 2>/dev/null | wc -l)
HA_CONFIG_COUNT=$(ls -1 /mnt/tank/backups/homelab/homeassistant/config-*.tar.gz 2>/dev/null | wc -l)
JELLYFIN_COUNT=$(ls -1 /mnt/tank/backups/homelab/jellyfin/full-*.tar.gz 2>/dev/null | wc -l)
TAILSCALE_COUNT=$(ls -1 /mnt/tank/backups/homelab/tailscale/state-*.tar.gz 2>/dev/null | wc -l)
TRAEFIK_COUNT=$(ls -1 /mnt/tank/backups/homelab/traefik/acme-*.tar.gz 2>/dev/null | wc -l)

echo "  Immich:          $IMMICH_DB_COUNT databases, $IMMICH_STORAGE_COUNT storage backups"
echo "  Vaultwarden:     $VAULT_DB_COUNT databases, $VAULT_RSA_COUNT RSA keys, $VAULT_ATT_COUNT attachments"
echo "  OtterWiki:       $WIKI_COUNT databases"
echo "  Home Assistant:  $HA_DB_COUNT databases, $HA_ZIGBEE_COUNT zigbee DBs, $HA_CONFIG_COUNT configs"
echo "  Jellyfin:        $JELLYFIN_COUNT full backups"
echo "  Tailscale:       $TAILSCALE_COUNT state backups"
echo "  Traefik:         $TRAEFIK_COUNT certificate backups"
echo ""

# Validate Vaultwarden backup set integrity
echo "Vaultwarden backup set validation:"
if [ $VAULT_DB_COUNT -eq $VAULT_RSA_COUNT ] && [ $VAULT_DB_COUNT -eq $VAULT_ATT_COUNT ]; then
  echo "  ✓ Complete backup sets: All databases have matching RSA keys and attachments"
else
  echo "  ⚠ WARNING: Incomplete backup sets detected!"
  echo "    Databases: $VAULT_DB_COUNT"
  echo "    RSA keys:  $VAULT_RSA_COUNT"
  echo "    Attachments: $VAULT_ATT_COUNT"
  echo "    Each backup should have 1 database + 1 RSA key + 1 attachment archive"
fi
echo ""

# Validate Home Assistant backup set integrity
echo "Home Assistant backup set validation:"
if [ $HA_DB_COUNT -gt 0 ]; then
  echo "  ✓ Main database backups found: $HA_DB_COUNT"
  if [ $HA_ZIGBEE_COUNT -eq $HA_DB_COUNT ]; then
    echo "  ✓ Complete backup sets: All main databases have matching Zigbee databases"
  elif [ $HA_ZIGBEE_COUNT -eq 0 ]; then
    echo "  ℹ No Zigbee databases (may not be configured)"
  else
    echo "  ⚠ WARNING: Partial Zigbee backups detected!"
    echo "    Main databases: $HA_DB_COUNT"
    echo "    Zigbee databases: $HA_ZIGBEE_COUNT"
  fi
else
  echo "  ✗ No Home Assistant backups found"
fi
echo ""

# Check backup sizes
echo "Total backup sizes:"
du -sh /mnt/tank/backups/homelab/immich /mnt/tank/backups/homelab/vaultwarden /mnt/tank/backups/homelab/wiki /mnt/tank/backups/homelab/homeassistant /mnt/tank/backups/homelab/jellyfin /mnt/tank/backups/homelab/tailscale /mnt/tank/backups/homelab/traefik 2>/dev/null
echo ""
du -sh /mnt/tank/backups/homelab 2>/dev/null | awk '{print "Total: " $1}'
echo ""