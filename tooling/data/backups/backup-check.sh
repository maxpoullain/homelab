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
echo -n "  Immich Postgres:  "
docker ps --format "{{.Names}}" | grep -q immich_postgres && echo "✓ Running" || echo "✗ Not running"
echo -n "  Vaultwarden:      "
docker ps --format "{{.Names}}" | grep -q vaultwarden && echo "✓ Running" || echo "✗ Not running"
echo -n "  Home Assistant:   "
docker ps --format "{{.Names}}" | grep -q "^ha$" && echo "✓ Running" || echo "✗ Not running"
echo -n "  Jellyfin:         "
docker ps --format "{{.Names}}" | grep -q jellyfin && echo "✓ Running" || echo "✗ Not running"
echo -n "  Tailscale:        "
docker ps --format "{{.Names}}" | grep -q tailscale && echo "✓ Running" || echo "✗ Not running"
echo -n "  Traefik:          "
docker ps --format "{{.Names}}" | grep -q traefik && echo "✓ Running" || echo "✗ Not running"
echo -n "  Prowlarr:         "
docker ps --format "{{.Names}}" | grep -q prowlarr && echo "✓ Running" || echo "✗ Not running"
echo -n "  Sonarr:           "
docker ps --format "{{.Names}}" | grep -q sonarr && echo "✓ Running" || echo "✗ Not running"
echo -n "  Radarr:           "
docker ps --format "{{.Names}}" | grep -q radarr && echo "✓ Running" || echo "✗ Not running"
echo -n "  Zigbee2mqtt:      "
docker ps --format "{{.Names}}" | grep -q zigbee2mqtt && echo "✓ Running" || echo "✗ Not running"
echo -n "  AdGuard:          "
docker ps --format "{{.Names}}" | grep -q adguard && echo "✓ Running" || echo "✗ Not running"
echo ""

# Check last backup time
echo "Last backup times:"
IMMICH_LAST=$(ls -lt /mnt/tank/backups/homelab/immich/db-*.sql.gz 2>/dev/null | head -1 | awk '{print $6, $7, $8, $9}')
VAULT_LAST=$(ls -lt /mnt/tank/backups/homelab/vaultwarden/db-*.sqlite3 2>/dev/null | head -1 | awk '{print $6, $7, $8, $9}')
HA_LAST=$(ls -lt /mnt/tank/backups/homelab/homeassistant/db-*.sqlite3 2>/dev/null | head -1 | awk '{print $6, $7, $8, $9}')
JELLYFIN_LAST=$(ls -lt /mnt/tank/backups/homelab/jellyfin/full-*.tar.gz 2>/dev/null | head -1 | awk '{print $6, $7, $8, $9}')
TAILSCALE_LAST=$(ls -lt /mnt/tank/backups/homelab/tailscale/state-*.tar.gz 2>/dev/null | head -1 | awk '{print $6, $7, $8, $9}')
TRAEFIK_LAST=$(ls -lt /mnt/tank/backups/homelab/traefik/acme-*.tar.gz 2>/dev/null | head -1 | awk '{print $6, $7, $8, $9}')
PROWLARR_LAST=$(ls -lt /mnt/tank/backups/homelab/prowlarr/full-*.tar.gz 2>/dev/null | head -1 | awk '{print $6, $7, $8, $9}')
SONARR_LAST=$(ls -lt /mnt/tank/backups/homelab/sonarr/full-*.tar.gz 2>/dev/null | head -1 | awk '{print $6, $7, $8, $9}')
RADARR_LAST=$(ls -lt /mnt/tank/backups/homelab/radarr/full-*.tar.gz 2>/dev/null | head -1 | awk '{print $6, $7, $8, $9}')
Z2M_LAST=$(ls -lt /mnt/tank/backups/homelab/zigbee2mqtt/full-*.tar.gz 2>/dev/null | head -1 | awk '{print $6, $7, $8, $9}')
ADGUARD_LAST=$(ls -lt /mnt/tank/backups/homelab/adguard/full-*.tar.gz 2>/dev/null | head -1 | awk '{print $6, $7, $8, $9}')

echo "  Immich:           ${IMMICH_LAST:-No backups found}"
echo "  Vaultwarden:      ${VAULT_LAST:-No backups found}"
echo "  Home Assistant:   ${HA_LAST:-No backups found}"
echo "  Jellyfin:         ${JELLYFIN_LAST:-No backups found}"
echo "  Tailscale:        ${TAILSCALE_LAST:-No backups found}"
echo "  Traefik:          ${TRAEFIK_LAST:-No backups found}"
echo "  Prowlarr:         ${PROWLARR_LAST:-No backups found}"
echo "  Sonarr:           ${SONARR_LAST:-No backups found}"
echo "  Radarr:           ${RADARR_LAST:-No backups found}"
echo "  Zigbee2mqtt:      ${Z2M_LAST:-No backups found}"
echo "  AdGuard:          ${ADGUARD_LAST:-No backups found}"
echo ""

# Check backup counts
echo "Backup file counts:"
IMMICH_DB_COUNT=$(ls -1 /mnt/tank/backups/homelab/immich/db-*.sql.gz 2>/dev/null | wc -l)
IMMICH_STORAGE_COUNT=$(ls -1 /mnt/tank/backups/homelab/immich/storage-*.tar.gz 2>/dev/null | wc -l)
VAULT_DB_COUNT=$(ls -1 /mnt/tank/backups/homelab/vaultwarden/db-*.sqlite3 2>/dev/null | wc -l)
VAULT_RSA_COUNT=$(ls -1 /mnt/tank/backups/homelab/vaultwarden/rsa_key-*.pem 2>/dev/null | wc -l)
VAULT_ATT_COUNT=$(ls -1 /mnt/tank/backups/homelab/vaultwarden/attachments-*.tar.gz 2>/dev/null | wc -l)
HA_DB_COUNT=$(ls -1 /mnt/tank/backups/homelab/homeassistant/db-*.sqlite3 2>/dev/null | wc -l)
HA_CONFIG_COUNT=$(ls -1 /mnt/tank/backups/homelab/homeassistant/config-*.tar.gz 2>/dev/null | wc -l)
JELLYFIN_COUNT=$(ls -1 /mnt/tank/backups/homelab/jellyfin/full-*.tar.gz 2>/dev/null | wc -l)
TAILSCALE_COUNT=$(ls -1 /mnt/tank/backups/homelab/tailscale/state-*.tar.gz 2>/dev/null | wc -l)
TRAEFIK_COUNT=$(ls -1 /mnt/tank/backups/homelab/traefik/acme-*.tar.gz 2>/dev/null | wc -l)
PROWLARR_COUNT=$(ls -1 /mnt/tank/backups/homelab/prowlarr/full-*.tar.gz 2>/dev/null | wc -l)
SONARR_COUNT=$(ls -1 /mnt/tank/backups/homelab/sonarr/full-*.tar.gz 2>/dev/null | wc -l)
RADARR_COUNT=$(ls -1 /mnt/tank/backups/homelab/radarr/full-*.tar.gz 2>/dev/null | wc -l)
Z2M_COUNT=$(ls -1 /mnt/tank/backups/homelab/zigbee2mqtt/full-*.tar.gz 2>/dev/null | wc -l)
ADGUARD_COUNT=$(ls -1 /mnt/tank/backups/homelab/adguard/full-*.tar.gz 2>/dev/null | wc -l)

echo "  Immich:           $IMMICH_DB_COUNT databases, $IMMICH_STORAGE_COUNT storage backups"
echo "  Vaultwarden:      $VAULT_DB_COUNT databases, $VAULT_RSA_COUNT RSA keys, $VAULT_ATT_COUNT attachments"
echo "  Home Assistant:   $HA_DB_COUNT databases, $HA_CONFIG_COUNT configs"
echo "  Jellyfin:         $JELLYFIN_COUNT full backups"
echo "  Tailscale:        $TAILSCALE_COUNT state backups"
echo "  Traefik:          $TRAEFIK_COUNT certificate backups"
echo "  Prowlarr:         $PROWLARR_COUNT full backups"
echo "  Sonarr:           $SONARR_COUNT full backups"
echo "  Radarr:           $RADARR_COUNT full backups"
echo "  Zigbee2mqtt:      $Z2M_COUNT full backups"
echo "  AdGuard:          $ADGUARD_COUNT full backups"
echo ""

# Validate Vaultwarden backup set integrity
echo "Vaultwarden backup set validation:"
if [ $VAULT_DB_COUNT -eq $VAULT_RSA_COUNT ] && [ $VAULT_DB_COUNT -eq $VAULT_ATT_COUNT ]; then
  echo "  ✓ Complete backup sets: All databases have matching RSA keys and attachments"
else
  echo "  ⚠ WARNING: Incomplete backup sets detected!"
  echo "    Databases:   $VAULT_DB_COUNT"
  echo "    RSA keys:    $VAULT_RSA_COUNT"
  echo "    Attachments: $VAULT_ATT_COUNT"
  echo "    Each backup should have 1 database + 1 RSA key + 1 attachment archive"
fi
echo ""

# Validate backup counts by tier
# Expected counts per service at steady state (rough upper bounds):
#   twice-daily: 2/day × 3 days = 6
#   daily:       1/day × 7 days = 7
#   weekly:      1/week × 4 weeks = 4
#   monthly:     1/month × 6 months = 6
echo "Backup counts by tier:"
TWICE_DAILY_COUNT=$(find /mnt/tank/backups/homelab -type f -name "*-twice-daily-*" | wc -l)
DAILY_COUNT=$(find /mnt/tank/backups/homelab -type f -name "*-daily-*" | wc -l)
WEEKLY_COUNT=$(find /mnt/tank/backups/homelab -type f -name "*-weekly-*" | wc -l)
MONTHLY_COUNT=$(find /mnt/tank/backups/homelab -type f -name "*-monthly-*" | wc -l)
TOTAL_COUNT=$((TWICE_DAILY_COUNT + DAILY_COUNT + WEEKLY_COUNT + MONTHLY_COUNT))
echo "  Twice-daily: $TWICE_DAILY_COUNT files"
echo "  Daily:       $DAILY_COUNT files"
echo "  Weekly:      $WEEKLY_COUNT files"
echo "  Monthly:     $MONTHLY_COUNT files"
echo "  Total:       $TOTAL_COUNT files"
echo ""

# ============================================
# TrueNAS Configuration Backups
# ============================================
echo "TrueNAS configuration backups:"
TRUENAS_BACKUP_DIR="/mnt/tank/backups/truenas"

if [ -d "$TRUENAS_BACKUP_DIR" ]; then
  # Count backup folders by type
  TN_DAILY_COUNT=$(find "$TRUENAS_BACKUP_DIR" -maxdepth 1 -type d -name "daily-*" 2>/dev/null | wc -l)
  TN_WEEKLY_COUNT=$(find "$TRUENAS_BACKUP_DIR" -maxdepth 1 -type d -name "weekly-*" 2>/dev/null | wc -l)
  TN_MONTHLY_COUNT=$(find "$TRUENAS_BACKUP_DIR" -maxdepth 1 -type d -name "monthly-*" 2>/dev/null | wc -l)

  echo "  Backup folders: $TN_DAILY_COUNT daily, $TN_WEEKLY_COUNT weekly, $TN_MONTHLY_COUNT monthly"

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
du -sh \
  /mnt/tank/backups/homelab/immich \
  /mnt/tank/backups/homelab/vaultwarden \
  /mnt/tank/backups/homelab/homeassistant \
  /mnt/tank/backups/homelab/jellyfin \
  /mnt/tank/backups/homelab/tailscale \
  /mnt/tank/backups/homelab/traefik \
  /mnt/tank/backups/homelab/prowlarr \
  /mnt/tank/backups/homelab/sonarr \
  /mnt/tank/backups/homelab/radarr \
  /mnt/tank/backups/homelab/zigbee2mqtt \
  /mnt/tank/backups/homelab/adguard \
  2>/dev/null
if [ -d "$TRUENAS_BACKUP_DIR" ]; then
  du -sh "$TRUENAS_BACKUP_DIR" 2>/dev/null
fi
echo ""
du -sh /mnt/tank/backups/homelab 2>/dev/null | awk '{print "Services total: " $1}'
if [ -d "$TRUENAS_BACKUP_DIR" ]; then
  du -sh /mnt/tank/backups 2>/dev/null | awk '{print "Grand total:    " $1}'
else
  du -sh /mnt/tank/backups/homelab 2>/dev/null | awk '{print "Grand total:    " $1}'
fi
echo ""

# ============================================
# B2 Offsite Storage Estimate
# ============================================
# B2 sync pushes weekly + monthly files only (daily-* and twice-daily-* are excluded).
# This mirrors the TrueNAS Cloud Sync exclude pattern: daily-*
echo "Estimated B2 offsite storage:"

# Sum weekly and monthly service backup files
B2_SERVICES_BYTES=$(find /mnt/tank/backups/homelab -type f \( -name "*-weekly-*" -o -name "*-monthly-*" \) \
  -exec stat -c%s {} + 2>/dev/null | awk '{sum += $1} END {print sum+0}')

# Sum weekly and monthly TrueNAS config folders
B2_TRUENAS_BYTES=0
if [ -d "$TRUENAS_BACKUP_DIR" ]; then
  B2_TRUENAS_BYTES=$(find "$TRUENAS_BACKUP_DIR" \( -path "*/weekly-*/*" -o -path "*/monthly-*/*" \) -type f \
    -exec stat -c%s {} + 2>/dev/null | awk '{sum += $1} END {print sum+0}')
fi

B2_TOTAL_BYTES=$((B2_SERVICES_BYTES + B2_TRUENAS_BYTES))

# Format bytes to human-readable (MB / GB)
B2_SERVICES_HUMAN=$(echo "$B2_SERVICES_BYTES" | awk '{
  if ($1 >= 1073741824) printf "%.1f GB", $1/1073741824
  else printf "%.1f MB", $1/1048576
}')
B2_TRUENAS_HUMAN=$(echo "$B2_TRUENAS_BYTES" | awk '{
  if ($1 >= 1073741824) printf "%.1f GB", $1/1073741824
  else printf "%.1f MB", $1/1048576
}')
B2_TOTAL_HUMAN=$(echo "$B2_TOTAL_BYTES" | awk '{
  if ($1 >= 1073741824) printf "%.1f GB", $1/1073741824
  else printf "%.1f MB", $1/1048576
}')

# Weekly/monthly file counts
B2_WEEKLY_COUNT=$(find /mnt/tank/backups/homelab -type f -name "*-weekly-*" 2>/dev/null | wc -l)
B2_MONTHLY_COUNT=$(find /mnt/tank/backups/homelab -type f -name "*-monthly-*" 2>/dev/null | wc -l)

echo "  Scope: weekly + monthly backups only (daily/twice-daily excluded from B2 sync)"
echo "  Service backups:  $B2_SERVICES_HUMAN  ($B2_WEEKLY_COUNT weekly files, $B2_MONTHLY_COUNT monthly files)"
if [ -d "$TRUENAS_BACKUP_DIR" ]; then
  echo "  TrueNAS config:   $B2_TRUENAS_HUMAN"
fi
echo "  ─────────────────────────"
echo "  Total synced to B2: $B2_TOTAL_HUMAN"

# Rough cost estimate at Backblaze B2 rate (~$0.006/GB/month)
B2_COST=$(echo "$B2_TOTAL_BYTES" | awk '{printf "%.2f", ($1/1073741824) * 0.006}')
echo "  Estimated B2 cost:  ~\$$B2_COST/month  (@\$0.006/GB)"
echo ""
