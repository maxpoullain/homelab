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

# ============================================
# Container status
# ============================================
echo "Container status:"
check_container() {
  local label=$1
  local name=$2
  local pad=$3
  printf "  %-${pad}s" "$label:"
  docker ps --format "{{.Names}}" | grep -q "^${name}$" && echo "✓ Running" || echo "✗ Not running"
}

check_container "Immich Postgres"  "immich_postgres"  18
check_container "Vaultwarden"      "vaultwarden"      18
check_container "Home Assistant"   "ha"               18
check_container "Jellyfin"         "jellyfin"         18
check_container "Traefik"          "traefik"          18
check_container "Prowlarr"         "prowlarr"         18
check_container "Sonarr"           "sonarr"           18
check_container "Radarr"           "radarr"           18
check_container "Zigbee2mqtt"      "zigbee2mqtt"      18
check_container "AdGuard"          "adguard"          18
check_container "Seerr"            "seerr"            18
check_container "Beszel"           "beszel"           18
check_container "Arcane"           "arcane"           18
check_container "Papra"            "papra"            18
check_container "OctoPrint"        "octoprint"        18
echo ""

# ============================================
# Last backup times
# ============================================
echo "Last backup times:"
last_backup() {
  local label=$1
  local glob=$2
  local pad=$3
  local result
  result=$(ls -lt ${glob} 2>/dev/null | head -1 | awk '{print $6, $7, $8}')
  printf "  %-${pad}s %s\n" "$label:" "${result:-No backups found}"
}

last_backup "Immich DB"        "/mnt/tank/backups/homelab/immich/db-*.sql.gz"              20
last_backup "Immich Storage"   "/mnt/tank/backups/homelab/immich/storage-*.tar.gz"         20
last_backup "Vaultwarden"      "/mnt/tank/backups/homelab/vaultwarden/db-*.sqlite3"        20
last_backup "Home Assistant"   "/mnt/tank/backups/homelab/homeassistant/db-*.sqlite3"      20
last_backup "Jellyfin"         "/mnt/tank/backups/homelab/jellyfin/full-*.tar.gz"          20
last_backup "Traefik"          "/mnt/tank/backups/homelab/traefik/acme-*.tar.gz"           20
last_backup "Prowlarr"         "/mnt/tank/backups/homelab/prowlarr/full-*.tar.gz"          20
last_backup "Sonarr"           "/mnt/tank/backups/homelab/sonarr/full-*.tar.gz"            20
last_backup "Radarr"           "/mnt/tank/backups/homelab/radarr/full-*.tar.gz"            20
last_backup "Zigbee2mqtt"      "/mnt/tank/backups/homelab/zigbee2mqtt/full-*.tar.gz"       20
last_backup "AdGuard"          "/mnt/tank/backups/homelab/adguard/full-*.tar.gz"           20
last_backup "Seerr"            "/mnt/tank/backups/homelab/seerr/full-*.tar.gz"             20
last_backup "Beszel"           "/mnt/tank/backups/homelab/beszel/full-*.tar.gz"            20
last_backup "Arcane"           "/mnt/tank/backups/homelab/arcane/db-*.sqlite3"             20
last_backup "Papra DB"         "/mnt/tank/backups/homelab/papra/db-*.sqlite3"              20
last_backup "Papra Documents"  "/mnt/tank/backups/homelab/papra/documents-*.tar.gz"        20
last_backup "OctoPrint"        "/mnt/tank/backups/homelab/octoprint/full-*.tar.gz"         20
echo ""

# ============================================
# Backup file counts
# ============================================
echo "Backup file counts:"
IMMICH_DB_COUNT=$(ls -1 /mnt/tank/backups/homelab/immich/db-*.sql.gz 2>/dev/null | wc -l)
IMMICH_STORAGE_COUNT=$(ls -1 /mnt/tank/backups/homelab/immich/storage-*.tar.gz 2>/dev/null | wc -l)
VAULT_DB_COUNT=$(ls -1 /mnt/tank/backups/homelab/vaultwarden/db-*.sqlite3 2>/dev/null | wc -l)
VAULT_RSA_COUNT=$(ls -1 /mnt/tank/backups/homelab/vaultwarden/rsa_key-*.pem 2>/dev/null | wc -l)
VAULT_ATT_COUNT=$(ls -1 /mnt/tank/backups/homelab/vaultwarden/attachments-*.tar.gz 2>/dev/null | wc -l)
HA_DB_COUNT=$(ls -1 /mnt/tank/backups/homelab/homeassistant/db-*.sqlite3 2>/dev/null | wc -l)
HA_CONFIG_COUNT=$(ls -1 /mnt/tank/backups/homelab/homeassistant/config-*.tar.gz 2>/dev/null | wc -l)
JELLYFIN_COUNT=$(ls -1 /mnt/tank/backups/homelab/jellyfin/full-*.tar.gz 2>/dev/null | wc -l)
TRAEFIK_COUNT=$(ls -1 /mnt/tank/backups/homelab/traefik/acme-*.tar.gz 2>/dev/null | wc -l)
PROWLARR_COUNT=$(ls -1 /mnt/tank/backups/homelab/prowlarr/full-*.tar.gz 2>/dev/null | wc -l)
SONARR_COUNT=$(ls -1 /mnt/tank/backups/homelab/sonarr/full-*.tar.gz 2>/dev/null | wc -l)
RADARR_COUNT=$(ls -1 /mnt/tank/backups/homelab/radarr/full-*.tar.gz 2>/dev/null | wc -l)
Z2M_COUNT=$(ls -1 /mnt/tank/backups/homelab/zigbee2mqtt/full-*.tar.gz 2>/dev/null | wc -l)
ADGUARD_COUNT=$(ls -1 /mnt/tank/backups/homelab/adguard/full-*.tar.gz 2>/dev/null | wc -l)
SEERR_COUNT=$(ls -1 /mnt/tank/backups/homelab/seerr/full-*.tar.gz 2>/dev/null | wc -l)
BESZEL_COUNT=$(ls -1 /mnt/tank/backups/homelab/beszel/full-*.tar.gz 2>/dev/null | wc -l)
ARCANE_COUNT=$(ls -1 /mnt/tank/backups/homelab/arcane/db-*.sqlite3 2>/dev/null | wc -l)
PAPRA_DB_COUNT=$(ls -1 /mnt/tank/backups/homelab/papra/db-*.sqlite3 2>/dev/null | wc -l)
PAPRA_DOCS_COUNT=$(ls -1 /mnt/tank/backups/homelab/papra/documents-*.tar.gz 2>/dev/null | wc -l)
OCTOPRINT_COUNT=$(ls -1 /mnt/tank/backups/homelab/octoprint/full-*.tar.gz 2>/dev/null | wc -l)

echo "  Immich:           $IMMICH_DB_COUNT databases, $IMMICH_STORAGE_COUNT storage backups"
echo "  Vaultwarden:      $VAULT_DB_COUNT databases, $VAULT_RSA_COUNT RSA keys, $VAULT_ATT_COUNT attachments"
echo "  Home Assistant:   $HA_DB_COUNT databases, $HA_CONFIG_COUNT configs"
echo "  Jellyfin:         $JELLYFIN_COUNT full backups"
echo "  Traefik:          $TRAEFIK_COUNT certificate backups"
echo "  Prowlarr:         $PROWLARR_COUNT full backups"
echo "  Sonarr:           $SONARR_COUNT full backups"
echo "  Radarr:           $RADARR_COUNT full backups"
echo "  Zigbee2mqtt:      $Z2M_COUNT full backups"
echo "  AdGuard:          $ADGUARD_COUNT full backups"
echo "  Seerr:            $SEERR_COUNT full backups"
echo "  Beszel:           $BESZEL_COUNT full backups"
echo "  Arcane:           $ARCANE_COUNT databases"
echo "  Papra:            $PAPRA_DB_COUNT databases, $PAPRA_DOCS_COUNT document archives"
echo "  OctoPrint:        $OCTOPRINT_COUNT full backups"
echo ""

# ============================================
# Backup set integrity checks
# ============================================
echo "Backup set integrity:"

# Vaultwarden: for every db-<type>-<timestamp>.sqlite3 there must be a matching
# rsa_key-<type>-<timestamp>.pem and attachments-<type>-<timestamp>.tar.gz.
# This per-run check is immune to historical count skew (e.g. RSA key backup was
# added after some db backups already existed).
VAULT_ORPHAN_DB=0
VAULT_ORPHAN_KEY=0
VAULT_COMPLETE=0
for db_file in /mnt/tank/backups/homelab/vaultwarden/db-*.sqlite3; do
  [ -f "$db_file" ] || continue
  # Extract the type+timestamp segment: db-daily-20251025-2236.sqlite3 → daily-20251025-2236
  ts=$(basename "$db_file" | sed 's/^db-//;s/\.sqlite3$//')
  key_file="/mnt/tank/backups/homelab/vaultwarden/rsa_key-${ts}.pem"
  att_file="/mnt/tank/backups/homelab/vaultwarden/attachments-${ts}.tar.gz"
  if [ -f "$key_file" ] && [ -f "$att_file" ]; then
    VAULT_COMPLETE=$((VAULT_COMPLETE + 1))
  else
    VAULT_ORPHAN_DB=$((VAULT_ORPHAN_DB + 1))
    [ ! -f "$key_file" ] && VAULT_ORPHAN_KEY=$((VAULT_ORPHAN_KEY + 1))
  fi
done
if [ "$VAULT_ORPHAN_DB" -eq 0 ] && [ "$VAULT_DB_COUNT" -gt 0 ]; then
  echo "  ✓ Vaultwarden: all $VAULT_COMPLETE sets complete (db + rsa_key + attachments)"
elif [ "$VAULT_DB_COUNT" -eq 0 ]; then
  echo "  ✗ Vaultwarden: no database backups found"
else
  echo "  ✗ Vaultwarden: $VAULT_ORPHAN_DB db backup(s) missing rsa_key or attachments ($VAULT_COMPLETE complete sets)"
  echo "      Run: ls /mnt/tank/backups/homelab/vaultwarden/ to inspect"
fi

# Immich: db + storage must match
if [ "$IMMICH_DB_COUNT" -eq "$IMMICH_STORAGE_COUNT" ]; then
  echo "  ✓ Immich: all sets complete ($IMMICH_DB_COUNT db / $IMMICH_STORAGE_COUNT storage)"
else
  echo "  ✗ Immich: MISMATCHED COUNTS"
  echo "      Databases: $IMMICH_DB_COUNT  |  Storage: $IMMICH_STORAGE_COUNT"
fi

# Home Assistant: db + config must match
if [ "$HA_DB_COUNT" -eq "$HA_CONFIG_COUNT" ]; then
  echo "  ✓ Home Assistant: all sets complete ($HA_DB_COUNT db / $HA_CONFIG_COUNT configs)"
else
  echo "  ✗ Home Assistant: MISMATCHED COUNTS"
  echo "      Databases: $HA_DB_COUNT  |  Configs: $HA_CONFIG_COUNT"
fi

# Papra: for every db-<type>-<timestamp>.sqlite3 there must be a matching
# documents-<type>-<timestamp>.tar.gz (when the documents directory is non-empty).
# Per-run check avoids false positives when old document archives have aged out
# of retention at a slightly different time than their matching db file.
PAPRA_ORPHAN_DB=0
PAPRA_COMPLETE=0
PAPRA_NO_DOCS=0
for papra_db in /mnt/tank/backups/homelab/papra/db-*.sqlite3; do
  [ -f "$papra_db" ] || continue
  ts=$(basename "$papra_db" | sed 's/^db-//;s/\.sqlite3$//')
  docs_file="/mnt/tank/backups/homelab/papra/documents-${ts}.tar.gz"
  if [ -f "$docs_file" ]; then
    PAPRA_COMPLETE=$((PAPRA_COMPLETE + 1))
  else
    # No documents archive is acceptable if there were no documents at backup time
    PAPRA_NO_DOCS=$((PAPRA_NO_DOCS + 1))
  fi
done
# Also flag documents archives with no matching db (retention timing orphans)
PAPRA_ORPHAN_DOCS=0
for papra_docs in /mnt/tank/backups/homelab/papra/documents-*.tar.gz; do
  [ -f "$papra_docs" ] || continue
  ts=$(basename "$papra_docs" | sed 's/^documents-//;s/\.tar\.gz$//')
  db_file="/mnt/tank/backups/homelab/papra/db-${ts}.sqlite3"
  [ ! -f "$db_file" ] && PAPRA_ORPHAN_DOCS=$((PAPRA_ORPHAN_DOCS + 1))
done
if [ "$PAPRA_ORPHAN_DOCS" -eq 0 ] && [ "$PAPRA_DB_COUNT" -gt 0 ]; then
  echo "  ✓ Papra: all sets consistent ($PAPRA_COMPLETE with docs / $PAPRA_NO_DOCS db-only / 0 orphaned doc archives)"
elif [ "$PAPRA_DB_COUNT" -eq 0 ] && [ "$PAPRA_DOCS_COUNT" -eq 0 ]; then
  echo "  ✗ Papra: no backups found"
else
  echo "  ✗ Papra: $PAPRA_ORPHAN_DOCS document archive(s) have no matching db backup"
  echo "      Run: ls /mnt/tank/backups/homelab/papra/ to inspect"
fi

# Check for orphaned Papra WAL/SHM files (no matching db)
PAPRA_ORPHANS=0
for wal_file in /mnt/tank/backups/homelab/papra/db-*.sqlite3-wal; do
  [ -f "$wal_file" ] || continue
  base="${wal_file%-wal}"
  [ ! -f "$base" ] && PAPRA_ORPHANS=$((PAPRA_ORPHANS + 1))
done
if [ "$PAPRA_ORPHANS" -gt 0 ]; then
  echo "  ✗ Papra: $PAPRA_ORPHANS orphaned WAL file(s) found (no matching .sqlite3)"
else
  echo "  ✓ Papra: no orphaned WAL/SHM files"
fi

echo ""

# ============================================
# Backup counts by retention tier
# ============================================
# Expected steady-state upper bounds per tier (all services combined):
#   twice-daily : 2/day × 3 days × N files/service
#   daily       : 1/day × 7 days × N files/service
#   weekly      : 1/week × 4 weeks × N files/service
#   monthly     : 1/month × 6 months × N files/service
echo "Backup counts by retention tier:"
TWICE_DAILY_COUNT=$(find /mnt/tank/backups/homelab -type f -name "*-twice-daily-*" | wc -l)
DAILY_COUNT=$(find /mnt/tank/backups/homelab -type f -name "*-daily-*" | wc -l)
WEEKLY_COUNT=$(find /mnt/tank/backups/homelab -type f -name "*-weekly-*" | wc -l)
MONTHLY_COUNT=$(find /mnt/tank/backups/homelab -type f -name "*-monthly-*" | wc -l)
TOTAL_COUNT=$((TWICE_DAILY_COUNT + DAILY_COUNT + WEEKLY_COUNT + MONTHLY_COUNT))
echo "  Twice-daily (kept 3 days):    $TWICE_DAILY_COUNT files"
echo "  Daily       (kept 7 days):    $DAILY_COUNT files"
echo "  Weekly      (kept 28 days):   $WEEKLY_COUNT files"
echo "  Monthly     (kept 180 days):  $MONTHLY_COUNT files"
echo "  ──────────────────────────────────────"
echo "  Total tracked:                $TOTAL_COUNT files"
echo ""

# Warn if the newest backup per tier is stale
check_freshness() {
  local tier=$1
  local max_age_hours=$2
  local newest
  newest=$(find /mnt/tank/backups/homelab -type f -name "*-${tier}-*" -printf '%T@\n' 2>/dev/null | sort -n | tail -1)
  if [ -z "$newest" ]; then
    echo "  ⚠  ${tier}: no files found"
    return
  fi
  local age_hours=$(( ( $(date +%s) - ${newest%.*} ) / 3600 ))
  if [ "$age_hours" -le "$max_age_hours" ]; then
    echo "  ✓  ${tier}: newest file is ${age_hours}h old (limit ${max_age_hours}h)"
  else
    echo "  ✗  ${tier}: newest file is ${age_hours}h old — STALE (limit ${max_age_hours}h)"
  fi
}

echo "Retention tier freshness:"
check_freshness "twice-daily" 30    # should run every ~12h; warn after 30h
check_freshness "daily"       36    # should run every ~24h; warn after 36h
check_freshness "weekly"      216   # should run every ~7d; warn after 9d
check_freshness "monthly"     960   # should run every ~30d; warn after 40d
echo ""

# ============================================
# TrueNAS configuration backups
# ============================================
echo "TrueNAS configuration backups:"
TRUENAS_BACKUP_DIR="/mnt/tank/backups/truenas"

if [ -d "$TRUENAS_BACKUP_DIR" ]; then
  TN_DAILY_COUNT=$(find "$TRUENAS_BACKUP_DIR" -maxdepth 1 -type d -name "daily-*" 2>/dev/null | wc -l)
  TN_WEEKLY_COUNT=$(find "$TRUENAS_BACKUP_DIR" -maxdepth 1 -type d -name "weekly-*" 2>/dev/null | wc -l)
  TN_MONTHLY_COUNT=$(find "$TRUENAS_BACKUP_DIR" -maxdepth 1 -type d -name "monthly-*" 2>/dev/null | wc -l)
  echo "  Backup folders: $TN_DAILY_COUNT daily, $TN_WEEKLY_COUNT weekly, $TN_MONTHLY_COUNT monthly"

  LAST_TN_BACKUP=$(find "$TRUENAS_BACKUP_DIR" -maxdepth 1 -type d -name "*-*" -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2-)
  if [ -n "$LAST_TN_BACKUP" ]; then
    LAST_TN_TIME=$(stat -c %y "$LAST_TN_BACKUP" 2>/dev/null | cut -d'.' -f1)
    LAST_TN_AGE=$(( ( $(date +%s) - $(stat -c %Y "$LAST_TN_BACKUP" 2>/dev/null) ) / 3600 ))
    if [ "$LAST_TN_AGE" -lt 48 ]; then
      echo "  ✓ Last backup: $LAST_TN_TIME (${LAST_TN_AGE}h ago)"
    else
      echo "  ✗ Last backup: $LAST_TN_TIME (${LAST_TN_AGE}h ago) — STALE"
    fi
  else
    echo "  ✗ No TrueNAS config backups found"
  fi

  echo ""
  echo "TrueNAS backup set validation:"
  INCOMPLETE_SETS=0
  TOTAL_TN_FOLDERS=0
  for folder in "$TRUENAS_BACKUP_DIR"/*-*/; do
    if [ -d "$folder" ]; then
      TOTAL_TN_FOLDERS=$((TOTAL_TN_FOLDERS + 1))
      FILE_COUNT=$(find "$folder" -maxdepth 1 -type f | wc -l)
      [ "$FILE_COUNT" -lt 5 ] && INCOMPLETE_SETS=$((INCOMPLETE_SETS + 1))
    fi
  done
  if [ "$INCOMPLETE_SETS" -eq 0 ] && [ "$TOTAL_TN_FOLDERS" -gt 0 ]; then
    echo "  ✓ All $TOTAL_TN_FOLDERS backup sets complete"
  elif [ "$TOTAL_TN_FOLDERS" -eq 0 ]; then
    echo "  ⚠ No backup folders found"
  else
    echo "  ✗ $INCOMPLETE_SETS of $TOTAL_TN_FOLDERS backup sets are incomplete"
    echo "    Each folder should have: truenas-config.tar.gz, ssh-keys.tar.gz,"
    echo "    ssl-certs.tar.gz, zfs-config.txt, network.txt, cronjobs.json"
  fi
  TN_SIZE=$(du -sh "$TRUENAS_BACKUP_DIR" 2>/dev/null | cut -f1)
  echo "  Total size: $TN_SIZE"
else
  echo "  ✗ TrueNAS backup directory not found: $TRUENAS_BACKUP_DIR"
  echo "  → Run: /mnt/fast/apps/homelab/tooling/data/backups/backup-truenas.sh"
fi
echo ""

# ============================================
# Disk usage by service
# ============================================
echo "Disk usage by service:"
for dir in \
  immich vaultwarden homeassistant jellyfin traefik \
  prowlarr sonarr radarr zigbee2mqtt adguard \
  seerr beszel arcane papra octoprint; do
  # (beszel was listed twice previously — now deduplicated)
  path="/mnt/tank/backups/homelab/$dir"
  if [ -d "$path" ]; then
    size=$(du -sh "$path" 2>/dev/null | cut -f1)
    printf "  %-16s %s\n" "$dir" "$size"
  fi
done
echo ""
du -sh /mnt/tank/backups/homelab 2>/dev/null | awk '{print "Services total:  " $1}'
if [ -d "$TRUENAS_BACKUP_DIR" ]; then
  du -sh /mnt/tank/backups 2>/dev/null | awk '{print "Grand total:     " $1}'
fi
echo ""

# ============================================
# B2 offsite storage estimate
# ============================================
# B2 sync pushes weekly + monthly files only (daily/twice-daily excluded).
echo "Estimated B2 offsite storage:"
B2_SERVICES_BYTES=$(find /mnt/tank/backups/homelab -type f \( -name "*-weekly-*" -o -name "*-monthly-*" \) \
  -exec stat -c%s {} + 2>/dev/null | awk '{sum += $1} END {print sum+0}')

B2_TRUENAS_BYTES=0
if [ -d "$TRUENAS_BACKUP_DIR" ]; then
  B2_TRUENAS_BYTES=$(find "$TRUENAS_BACKUP_DIR" \( -path "*/weekly-*/*" -o -path "*/monthly-*/*" \) -type f \
    -exec stat -c%s {} + 2>/dev/null | awk '{sum += $1} END {print sum+0}')
fi

B2_TOTAL_BYTES=$((B2_SERVICES_BYTES + B2_TRUENAS_BYTES))

fmt_bytes() {
  echo "$1" | awk '{
    if ($1 >= 1073741824) printf "%.1f GB", $1/1073741824
    else printf "%.1f MB", $1/1048576
  }'
}

B2_WEEKLY_COUNT=$(find /mnt/tank/backups/homelab -type f -name "*-weekly-*" 2>/dev/null | wc -l)
B2_MONTHLY_COUNT=$(find /mnt/tank/backups/homelab -type f -name "*-monthly-*" 2>/dev/null | wc -l)

echo "  Scope: weekly + monthly backups only (daily/twice-daily excluded from B2 sync)"
echo "  Service backups:  $(fmt_bytes $B2_SERVICES_BYTES)  ($B2_WEEKLY_COUNT weekly files, $B2_MONTHLY_COUNT monthly files)"
[ -d "$TRUENAS_BACKUP_DIR" ] && echo "  TrueNAS config:   $(fmt_bytes $B2_TRUENAS_BYTES)"
echo "  ─────────────────────────────────────────"
echo "  Total synced to B2: $(fmt_bytes $B2_TOTAL_BYTES)"
B2_COST=$(echo "$B2_TOTAL_BYTES" | awk '{printf "%.2f", ($1/1073741824) * 0.006}')
echo "  Estimated B2 cost:  ~\$$B2_COST/month  (@\$0.006/GB)"
echo ""
