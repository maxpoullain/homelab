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
echo -n "  Prowlarr: "
docker ps --format "{{.Names}}" | grep -q prowlarr && echo "✓ Running" || echo "✗ Not running"
echo -n "  Sonarr: "
docker ps --format "{{.Names}}" | grep -q sonarr && echo "✓ Running" || echo "✗ Not running"
echo -n "  Radarr: "
docker ps --format "{{.Names}}" | grep -q radarr && echo "✓ Running" || echo "✗ Not running"
echo -n "  Readarr: "
docker ps --format "{{.Names}}" | grep -q readarr && echo "✓ Running" || echo "✗ Not running"
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
PROWLARR_LAST=$(ls -lt /mnt/tank/backups/homelab/prowlarr/full-*.tar.gz 2>/dev/null | head -1 | awk '{print $6, $7, $8, $9}')
SONARR_LAST=$(ls -lt /mnt/tank/backups/homelab/sonarr/full-*.tar.gz 2>/dev/null | head -1 | awk '{print $6, $7, $8, $9}')
RADARR_LAST=$(ls -lt /mnt/tank/backups/homelab/radarr/full-*.tar.gz 2>/dev/null | head -1 | awk '{print $6, $7, $8, $9}')
READARR_LAST=$(ls -lt /mnt/tank/backups/homelab/readarr/full-*.tar.gz 2>/dev/null | head -1 | awk '{print $6, $7, $8, $9}')

echo "  Immich:          ${IMMICH_LAST:-No backups found}"
echo "  Vaultwarden:     ${VAULT_LAST:-No backups found}"
echo "  OtterWiki:       ${WIKI_LAST:-No backups found}"
echo "  Home Assistant:  ${HA_LAST:-No backups found}"
echo "  Jellyfin:        ${JELLYFIN_LAST:-No backups found}"
echo "  Tailscale:       ${TAILSCALE_LAST:-No backups found}"
echo "  Traefik:         ${TRAEFIK_LAST:-No backups found}"
echo "  Prowlarr:        ${PROWLARR_LAST:-No backups found}"
echo "  Sonarr:          ${SONARR_LAST:-No backups found}"
echo "  Radarr:          ${RADARR_LAST:-No backups found}"
echo "  Readarr:         ${READARR_LAST:-No backups found}"
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
PROWLARR_COUNT=$(ls -1 /mnt/tank/backups/homelab/prowlarr/full-*.tar.gz 2>/dev/null | wc -l)
SONARR_COUNT=$(ls -1 /mnt/tank/backups/homelab/sonarr/full-*.tar.gz 2>/dev/null | wc -l)
RADARR_COUNT=$(ls -1 /mnt/tank/backups/homelab/radarr/full-*.tar.gz 2>/dev/null | wc -l)
READARR_COUNT=$(ls -1 /mnt/tank/backups/homelab/readarr/full-*.tar.gz 2>/dev/null | wc -l)
READARR_CONFIG_COUNT=$(ls -1 /mnt/tank/backups/homelab/readarr/config-*.tar.gz 2>/dev/null | wc -l)

echo "  Immich:          $IMMICH_DB_COUNT databases, $IMMICH_STORAGE_COUNT storage backups"
echo "  Vaultwarden:     $VAULT_DB_COUNT databases, $VAULT_RSA_COUNT RSA keys, $VAULT_ATT_COUNT attachments"
echo "  OtterWiki:       $WIKI_COUNT databases"
echo "  Home Assistant:  $HA_DB_COUNT databases, $HA_ZIGBEE_COUNT zigbee DBs, $HA_CONFIG_COUNT configs"
echo "  Jellyfin:        $JELLYFIN_COUNT full backups"
echo "  Tailscale:       $TAILSCALE_COUNT state backups"
echo "  Traefik:         $TRAEFIK_COUNT certificate backups"
echo "  Prowlarr:        $PROWLARR_COUNT full backups"
echo "  Sonarr:          $SONARR_COUNT full backups"
echo "  Radarr:          $RADARR_COUNT full backups"
echo "  Readarr:         $READARR_COUNT full backups"
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

# ============================================
# TrueNAS Configuration Backups
# ============================================
echo "TrueNAS configuration backups:"
TRUENAS_BACKUP_DIR="/mnt/tank/backups/truenas"

if [ -d "$TRUENAS_BACKUP_DIR" ]; then
  # Count backup folders by type
  DAILY_COUNT=$(find "$TRUENAS_BACKUP_DIR" -maxdepth 1 -type d -name "daily-*" 2>/dev/null | wc -l)
  WEEKLY_COUNT=$(find "$TRUENAS_BACKUP_DIR" -maxdepth 1 -type d -name "weekly-*" 2>/dev/null | wc -l)
  MONTHLY_COUNT=$(find "$TRUENAS_BACKUP_DIR" -maxdepth 1 -type d -name "monthly-*" 2>/dev/null | wc -l)
  TOTAL_TN_COUNT=$((DAILY_COUNT + WEEKLY_COUNT + MONTHLY_COUNT))
  
  echo "  Backup folders: $DAILY_COUNT daily, $WEEKLY_COUNT weekly, $MONTHLY_COUNT monthly"
  
  # Check last backup time
  LAST_TN_BACKUP=$(find "$TRUENAS_BACKUP_DIR" -maxdepth 1 -type d -name "*-*" -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2-)
  if [ -n "$LAST_TN_BACKUP" ]; then
    LAST_TN_TIME=$(stat -c %y "$LAST_TN_BACKUP" 2>/dev/null | cut -d'.' -f1)
    LAST_TN_AGE=$(($(date +%s) - $(stat -c %Y "$LAST_TN_BACKUP" 2>/dev/null)))
    LAST_TN_HOURS=$((LAST_TN_AGE / 3600))
    
    if [ $LAST_TN_HOURS -lt 48 ]; then
      echo "  ✓ Last backup: $LAST_TN_TIME ($LAST_TN_HOURS hours ago)"
    else
      echo "  ⚠ Last backup: $LAST_TN_TIME ($LAST_TN_HOURS hours ago) - May be stale"
    fi
  else
    echo "  ✗ No TrueNAS config backups found"
  fi
  
  # Validate backup folder completeness (should have 6 files per folder)
  echo ""
  echo "TrueNAS backup set validation:"
  
  INCOMPLETE_SETS=0
  TOTAL_FOLDERS=0
  
  for folder in "$TRUENAS_BACKUP_DIR"/*-*/; do
    if [ -d "$folder" ]; then
      TOTAL_FOLDERS=$((TOTAL_FOLDERS + 1))
      FILE_COUNT=$(find "$folder" -maxdepth 1 -type f | wc -l)
      
      # Each backup folder should have 6 files (SSL may be optional, so 5 is OK)
      if [ $FILE_COUNT -lt 5 ]; then
        INCOMPLETE_SETS=$((INCOMPLETE_SETS + 1))
      fi
    fi
  done
  
  if [ $INCOMPLETE_SETS -eq 0 ] && [ $TOTAL_FOLDERS -gt 0 ]; then
    echo "  ✓ All $TOTAL_FOLDERS backup sets complete (6 files per backup)"
  elif [ $TOTAL_FOLDERS -eq 0 ]; then
    echo "  ⚠ No backup folders found"
  else
    echo "  ⚠ WARNING: $INCOMPLETE_SETS incomplete backup sets detected!"
    echo "    Each backup folder should have: truenas-config.tar.gz, ssh-keys.tar.gz,"
    echo "    ssl-certs.tar.gz, zfs-config.txt, network.txt, cronjobs.json"
  fi
  
  # Disk usage
  TN_SIZE=$(du -sh "$TRUENAS_BACKUP_DIR" 2>/dev/null | cut -f1)
  echo "  Total size: $TN_SIZE"
else
  echo "  ✗ TrueNAS backup directory not found: $TRUENAS_BACKUP_DIR"
  echo "  → Run: /mnt/fast/apps/homelab/tooling/data/backups/backup-truenas.sh"
fi
echo ""

# Check backup sizes
echo "Total backup sizes:"
du -sh /mnt/tank/backups/homelab/immich /mnt/tank/backups/homelab/vaultwarden /mnt/tank/backups/homelab/wiki /mnt/tank/backups/homelab/homeassistant /mnt/tank/backups/homelab/jellyfin /mnt/tank/backups/homelab/tailscale /mnt/tank/backups/homelab/traefik /mnt/tank/backups/homelab/prowlarr /mnt/tank/backups/homelab/sonarr /mnt/tank/backups/homelab/radarr /mnt/tank/backups/homelab/readarr 2>/dev/null
if [ -d "$TRUENAS_BACKUP_DIR" ]; then
  du -sh "$TRUENAS_BACKUP_DIR" 2>/dev/null | awk '{print $1 "\t" $2}'
fi
echo ""
du -sh /mnt/tank/backups/homelab 2>/dev/null | awk '{print "Services total: " $1}'
if [ -d "$TRUENAS_BACKUP_DIR" ]; then
  du -sh /mnt/tank/backups 2>/dev/null | awk '{print "Grand total:    " $1}'
else
  du -sh /mnt/tank/backups/homelab 2>/dev/null | awk '{print "Grand total:    " $1}'
fi
echo ""