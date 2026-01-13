#!/bin/bash

# Homelab Services Backup Script
# Consolidates database and application backups for all services
# Each service section handles its complete backup (databases + configs + files)
#
# NOTE: Service paths updated for 2025:
#   - Tailscale:   $APPS_BASE/network/tailscale
#   - Traefik:     $APPS_BASE/front/traefik
#   - AdGuard:     $APPS_BASE/dns/adguard
#
# Usage:
#   ./backup-services.sh                    # Backup all services
#   ./backup-services.sh immich vaultwarden # Backup only specified services
#   ./backup-services.sh --list             # List available services

set +e  # Don't exit on errors - we want to continue even if one service fails

# Configuration
BACKUP_DIR="/mnt/tank/backups/homelab"
APPS_BASE="/mnt/fast/apps/homelab"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$SCRIPT_DIR/backup-services.log"
DATE=$(date +%Y%m%d-%H%M)
DAY_OF_WEEK=$(date +%u)  # 1-7 (Monday-Sunday)
DAY_OF_MONTH=$(date +%d)
HOUR=$(date +%H)

# Available services
AVAILABLE_SERVICES=(immich vaultwarden homeassistant jellyfin tailscale traefik prowlarr sonarr radarr readarr zigbee2mqtt adguard)

# Parse command line arguments
SELECTED_SERVICES=()
if [ $# -eq 0 ]; then
  # No arguments - backup all services
  SELECTED_SERVICES=("${AVAILABLE_SERVICES[@]}")
elif [ "$1" = "--list" ] || [ "$1" = "-l" ]; then
  echo "Available services:"
  for service in "${AVAILABLE_SERVICES[@]}"; do
    echo "  - $service"
  done
  exit 0
elif [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
  echo "Usage: $0 [SERVICE...]"
  echo ""
  echo "Backup homelab services. If no services specified, all services are backed up."
  echo ""
  echo "Options:"
  echo "  -l, --list    List available services"
  echo "  -h, --help    Show this help message"
  echo ""
  echo "Available services:"
  for service in "${AVAILABLE_SERVICES[@]}"; do
    echo "  - $service"
  done
  echo ""
  echo "Examples:"
  echo "  $0                           # Backup all services"
  echo "  $0 immich vaultwarden        # Backup only Immich and Vaultwarden"
  echo "  $0 prowlarr sonarr radarr    # Backup only *arr services"
  exit 0
else
  # Validate provided services
  for arg in "$@"; do
    found=false
    for service in "${AVAILABLE_SERVICES[@]}"; do
      if [ "$arg" = "$service" ]; then
        SELECTED_SERVICES+=("$arg")
        found=true
        break
      fi
    done
    if [ "$found" = false ]; then
      echo "Error: Unknown service '$arg'"
      echo "Run '$0 --list' to see available services"
      exit 1
    fi
  done
fi

# Rotate log file if it's larger than 10MB
if [ -f "$LOG_FILE" ] && [ $(stat -f%z "$LOG_FILE" 2>/dev/null || stat -c%s "$LOG_FILE" 2>/dev/null) -gt 10485760 ]; then
  mv "$LOG_FILE" "$LOG_FILE.old"
  rm -f "$LOG_FILE.old.old" 2>/dev/null
fi

# Determine backup type based on time
# 7 PM (19:00) is used for daily/weekly/monthly, 7 AM is twice-daily
if [ "$DAY_OF_MONTH" = "01" ] && [ "$HOUR" = "19" ]; then
  BACKUP_TYPE="monthly"
  RETENTION_DAYS=180  # 6 months
elif [ "$DAY_OF_WEEK" = "7" ] && [ "$HOUR" = "19" ]; then
  BACKUP_TYPE="weekly"
  RETENTION_DAYS=28   # 4 weeks
elif [ "$HOUR" = "19" ]; then
  BACKUP_TYPE="daily"
  RETENTION_DAYS=7    # 7 days
else
  BACKUP_TYPE="twice-daily"
  RETENTION_DAYS=3    # 3 days (keeps 6 backups: 2 per day × 3 days)
fi

# Track success/failure
TOTAL_SERVICES=${#SELECTED_SERVICES[@]}
SUCCESSFUL_BACKUPS=0
FAILED_BACKUPS=0
BACKUP_STATUS=""

# Helper function to check if service should be backed up
should_backup() {
  local service=$1
  for selected in "${SELECTED_SERVICES[@]}"; do
    if [ "$selected" = "$service" ]; then
      return 0
    fi
  done
  return 1
}

# Logging function
log() {
  echo "$1" | tee -a "$LOG_FILE"
}

log ""
log "=========================================="
log "=== Homelab Services Backup Started ==="
log "Date: $(date)"
log "Backup type: $BACKUP_TYPE"
log "Retention: $RETENTION_DAYS days"
if [ ${#SELECTED_SERVICES[@]} -eq ${#AVAILABLE_SERVICES[@]} ]; then
  log "Services: ALL (${#SELECTED_SERVICES[@]})"
else
  log "Services: ${SELECTED_SERVICES[*]} (${#SELECTED_SERVICES[@]})"
fi
log "=========================================="
log ""

# Create backup directories if they don't exist
mkdir -p "$BACKUP_DIR"/{immich,vaultwarden,homeassistant,jellyfin,tailscale,traefik,prowlarr,sonarr,radarr,readarr,zigbee2mqtt,adguard}

# ============================================
# IMMICH - PostgreSQL Database + Storage
# ============================================
if should_backup "immich"; then
log "Backing up Immich (database + storage)..."
IMMICH_SUCCESS=true

# 1. Backup PostgreSQL database
if docker ps --format "{{.Names}}" | grep -q immich_postgres; then
  IMMICH_DB_FILE="$BACKUP_DIR/immich/db-${BACKUP_TYPE}-$DATE.sql.gz"
  
  if docker exec -t immich_postgres pg_dumpall --clean --if-exists --username=postgres | gzip > "$IMMICH_DB_FILE" 2>&1; then
    IMMICH_DB_SIZE=$(du -h "$IMMICH_DB_FILE" | cut -f1)
    log "  ✓ Database backed up: db-${BACKUP_TYPE}-$DATE.sql.gz ($IMMICH_DB_SIZE)"
  else
    log "  ✗ Database backup failed"
    IMMICH_SUCCESS=false
  fi
else
  log "  ✗ immich_postgres container not running"
  IMMICH_SUCCESS=false
fi

# 2. Backup storage files (library, upload, profile only - exclude regenerable content)
if [ -d "$APPS_BASE/media/immich" ] && [ "$IMMICH_SUCCESS" = true ]; then
  IMMICH_STORAGE_FILE="$BACKUP_DIR/immich/storage-${BACKUP_TYPE}-$DATE.tar.gz"
  
  tar -czf "$IMMICH_STORAGE_FILE" \
    --exclude="thumbs" \
    --exclude="encoded-video" \
    --exclude="backups" \
    -C "$APPS_BASE/media/immich" . 2>&1 | grep -v "Removing leading" || true
  
  if [ -f "$IMMICH_STORAGE_FILE" ]; then
    IMMICH_STORAGE_SIZE=$(du -h "$IMMICH_STORAGE_FILE" | cut -f1)
    log "  ✓ Storage backed up: storage-${BACKUP_TYPE}-$DATE.tar.gz ($IMMICH_STORAGE_SIZE)"
    log "    Includes: library/, upload/, profile/"
    log "    Excludes: thumbs/ (29GB, regenerable), encoded-video/ (1.3GB, regenerable)"
  else
    log "  ✗ Storage backup failed"
    IMMICH_SUCCESS=false
  fi
else
  if [ "$IMMICH_SUCCESS" = true ]; then
    log "  ✗ Storage directory not found"
    IMMICH_SUCCESS=false
  fi
fi

if [ "$IMMICH_SUCCESS" = true ]; then
  SUCCESSFUL_BACKUPS=$((SUCCESSFUL_BACKUPS + 1))
  BACKUP_STATUS="${BACKUP_STATUS}Immich: ✓ SUCCESS\n"
else
  FAILED_BACKUPS=$((FAILED_BACKUPS + 1))
  BACKUP_STATUS="${BACKUP_STATUS}Immich: ✗ FAILED\n"
fi
log ""
fi

# ============================================
# VAULTWARDEN - SQLite Database + RSA Keys + Attachments
# ============================================
if should_backup "vaultwarden"; then
log "Backing up Vaultwarden (database + keys + attachments)..."
VAULTWARDEN_SUCCESS=true

if docker ps --format "{{.Names}}" | grep -q vaultwarden; then
  VAULT_DB_FILE="$BACKUP_DIR/vaultwarden/db-${BACKUP_TYPE}-$DATE.sqlite3"
  
  # 1. Backup database using built-in backup command
  BACKUP_OUTPUT=$(docker exec vaultwarden /vaultwarden backup 2>&1 | tee -a "$LOG_FILE")
  
  # Extract the actual backup filename from the output (e.g., "db_20251025_211508.sqlite3")
  BACKUP_FILENAME=$(echo "$BACKUP_OUTPUT" | grep -oE "db_[0-9]+_[0-9]+\.sqlite3")
  
  if [ -n "$BACKUP_FILENAME" ]; then
    if docker cp "vaultwarden:/data/$BACKUP_FILENAME" "$VAULT_DB_FILE" 2>&1; then
      VAULT_DB_SIZE=$(du -h "$VAULT_DB_FILE" | cut -f1)
      log "  ✓ Database backed up: db-${BACKUP_TYPE}-$DATE.sqlite3 ($VAULT_DB_SIZE)"
      docker exec vaultwarden rm -f "/data/$BACKUP_FILENAME" 2>/dev/null
    else
      log "  ✗ Database backup failed - could not copy backup file"
      VAULTWARDEN_SUCCESS=false
    fi
  else
    log "  ✗ Database backup failed - could not determine backup filename"
    VAULTWARDEN_SUCCESS=false
  fi
  
  # Only continue if database backup succeeded
  if [ "$VAULTWARDEN_SUCCESS" = true ]; then
    # 2. Backup RSA keys
    VAULT_KEY_FILE="$BACKUP_DIR/vaultwarden/rsa_key-${BACKUP_TYPE}-$DATE.pem"
    if docker cp "vaultwarden:/data/rsa_key.pem" "$VAULT_KEY_FILE" 2>&1; then
      log "  ✓ RSA key backed up: rsa_key-${BACKUP_TYPE}-$DATE.pem"
    else
      log "  ✗ RSA key backup failed"
      VAULTWARDEN_SUCCESS=false
    fi
    
    # 3. Backup attachments if they exist (only if previous steps succeeded)
    if [ "$VAULTWARDEN_SUCCESS" = true ]; then
      VAULT_ATT_FILE="$BACKUP_DIR/vaultwarden/attachments-${BACKUP_TYPE}-$DATE.tar.gz"
      if docker exec vaultwarden test -d /data/attachments 2>/dev/null; then
        docker exec vaultwarden tar -czf /tmp/attachments.tar.gz -C /data attachments 2>&1
        if docker cp "vaultwarden:/tmp/attachments.tar.gz" "$VAULT_ATT_FILE" 2>&1; then
          VAULT_ATT_SIZE=$(du -h "$VAULT_ATT_FILE" | cut -f1)
          log "  ✓ Attachments backed up: attachments-${BACKUP_TYPE}-$DATE.tar.gz ($VAULT_ATT_SIZE)"
          docker exec vaultwarden rm -f /tmp/attachments.tar.gz 2>/dev/null
        else
          log "  ✗ Attachments backup failed"
          VAULTWARDEN_SUCCESS=false
        fi
      else
        log "  ℹ No attachments directory found"
        # Create empty placeholder to maintain backup set consistency
        touch "$VAULT_ATT_FILE"
      fi
    fi
    
    # Cleanup incomplete backups if any step failed
    if [ "$VAULTWARDEN_SUCCESS" = false ]; then
      rm -f "$VAULT_DB_FILE" "$VAULT_KEY_FILE" "$VAULT_ATT_FILE"
    fi
  fi
else
  log "  ✗ vaultwarden container not running"
  VAULTWARDEN_SUCCESS=false
fi

if [ "$VAULTWARDEN_SUCCESS" = true ]; then
  SUCCESSFUL_BACKUPS=$((SUCCESSFUL_BACKUPS + 1))
  BACKUP_STATUS="${BACKUP_STATUS}Vaultwarden: ✓ SUCCESS\n"
else
  FAILED_BACKUPS=$((FAILED_BACKUPS + 1))
  BACKUP_STATUS="${BACKUP_STATUS}Vaultwarden: ✗ FAILED\n"
fi
log ""
fi

# ============================================
# HOME ASSISTANT - SQLite Databases + YAML Configs
# ============================================
if should_backup "homeassistant"; then
log "Backing up Home Assistant (databases + configs)..."
HA_SUCCESS=true

# 1. Backup main database
if docker ps --format "{{.Names}}" | grep -q "^ha$"; then
  HA_DB_FILE="$BACKUP_DIR/homeassistant/db-${BACKUP_TYPE}-$DATE.sqlite3"
  
  if docker exec ha python3 -c "import sqlite3; src=sqlite3.connect('/config/home-assistant_v2.db'); dst=sqlite3.connect('/tmp/ha-backup.db'); src.backup(dst); src.close(); dst.close()" 2>&1 | tee -a "$LOG_FILE"; then
    if docker cp "ha:/tmp/ha-backup.db" "$HA_DB_FILE" 2>&1; then
      HA_DB_SIZE=$(du -h "$HA_DB_FILE" | cut -f1)
      log "  ✓ Main database backed up: db-${BACKUP_TYPE}-$DATE.sqlite3 ($HA_DB_SIZE)"
      docker exec ha rm -f /tmp/ha-backup.db 2>/dev/null
    else
      log "  ✗ Main database backup failed - could not copy backup file"
      HA_SUCCESS=false
    fi
  else
    log "  ✗ Main database backup failed - Python backup command failed"
    HA_SUCCESS=false
  fi
else
  log "  ✗ ha container not running"
  HA_SUCCESS=false
fi

# 2. Backup YAML configuration files
if [ -d "$APPS_BASE/home/ha" ] && [ "$HA_SUCCESS" = true ]; then
  HA_CONFIG_FILE="$BACKUP_DIR/homeassistant/config-${BACKUP_TYPE}-$DATE.tar.gz"
  
  tar -czf "$HA_CONFIG_FILE" \
    --exclude="home-assistant_v2.db*" \
    --exclude="*.log*" \
    --exclude=".storage" \
    --exclude="deps" \
    --exclude="tts" \
    --exclude="image" \
    -C "$APPS_BASE/home" ha 2>&1 | grep -v "Removing leading" || true
  
  if [ -f "$HA_CONFIG_FILE" ]; then
    HA_CONFIG_SIZE=$(du -h "$HA_CONFIG_FILE" | cut -f1)
    log "  ✓ Configs backed up: config-${BACKUP_TYPE}-$DATE.tar.gz ($HA_CONFIG_SIZE)"
    log "    Includes: automations.yaml, configuration.yaml, scripts.yaml, etc."
  else
    log "  ✗ Config backup failed"
    HA_SUCCESS=false
  fi
else
  if [ "$HA_SUCCESS" = true ]; then
    log "  ✗ Config directory not found"
    HA_SUCCESS=false
  fi
fi

if [ "$HA_SUCCESS" = true ]; then
  SUCCESSFUL_BACKUPS=$((SUCCESSFUL_BACKUPS + 1))
  BACKUP_STATUS="${BACKUP_STATUS}Home Assistant: ✓ SUCCESS\n"
else
  FAILED_BACKUPS=$((FAILED_BACKUPS + 1))
  BACKUP_STATUS="${BACKUP_STATUS}Home Assistant: ✗ FAILED\n"
fi
log ""
fi

# ============================================
# JELLYFIN - Full Backup (Databases + Configs + Metadata)
# ============================================
if should_backup "jellyfin"; then
log "Backing up Jellyfin (full backup)..."
JELLYFIN_SUCCESS=true

if [ -d "$APPS_BASE/media/jellyfin/config" ]; then
  if docker ps --format "{{.Names}}" | grep -q jellyfin; then
    JELLYFIN_FILE="$BACKUP_DIR/jellyfin/full-${BACKUP_TYPE}-$DATE.tar.gz"
    
    tar -czf "$JELLYFIN_FILE" \
      --exclude="cache" \
      --exclude="log" \
      --exclude="transcodes" \
      -C "$APPS_BASE/media/jellyfin" config 2>&1 | grep -v "Removing leading" || true
    
    if [ -f "$JELLYFIN_FILE" ]; then
      JELLYFIN_SIZE=$(du -h "$JELLYFIN_FILE" | cut -f1)
      log "  ✓ Full backup completed: full-${BACKUP_TYPE}-$DATE.tar.gz ($JELLYFIN_SIZE)"
      log "    Includes: databases, metadata, plugins, settings"
      log "    Excludes: cache, logs, transcodes"
      SUCCESSFUL_BACKUPS=$((SUCCESSFUL_BACKUPS + 1))
      BACKUP_STATUS="${BACKUP_STATUS}Jellyfin: ✓ SUCCESS\n"
    else
      log "  ✗ Backup failed"
      FAILED_BACKUPS=$((FAILED_BACKUPS + 1))
      BACKUP_STATUS="${BACKUP_STATUS}Jellyfin: ✗ FAILED\n"
    fi
  else
    log "  ✗ jellyfin container not running"
    FAILED_BACKUPS=$((FAILED_BACKUPS + 1))
    BACKUP_STATUS="${BACKUP_STATUS}Jellyfin: ✗ FAILED (container not running)\n"
  fi
else
  log "  ✗ Jellyfin config directory not found"
  FAILED_BACKUPS=$((FAILED_BACKUPS + 1))
  BACKUP_STATUS="${BACKUP_STATUS}Jellyfin: ✗ FAILED\n"
fi
log ""
fi

# ============================================
# TAILSCALE - State Files
# ============================================
if should_backup "tailscale"; then
log "Backing up Tailscale (state files)..."
TAILSCALE_SUCCESS=true

if [ -d "$APPS_BASE/network/tailscale" ]; then
  TAILSCALE_FILE="$BACKUP_DIR/tailscale/state-${BACKUP_TYPE}-$DATE.tar.gz"
  
  tar -czf "$TAILSCALE_FILE" \
    --exclude="*.log*" \
    --exclude="*.txt" \
    -C "$APPS_BASE/network" tailscale 2>&1 | grep -v "Removing leading" || true
  
  if [ -f "$TAILSCALE_FILE" ]; then
    TAILSCALE_SIZE=$(du -h "$TAILSCALE_FILE" | cut -f1)
    log "  ✓ State backed up: state-${BACKUP_TYPE}-$DATE.tar.gz ($TAILSCALE_SIZE)"
    SUCCESSFUL_BACKUPS=$((SUCCESSFUL_BACKUPS + 1))
    BACKUP_STATUS="${BACKUP_STATUS}Tailscale: ✓ SUCCESS\n"
  else
    log "  ✗ Backup failed"
    FAILED_BACKUPS=$((FAILED_BACKUPS + 1))
    BACKUP_STATUS="${BACKUP_STATUS}Tailscale: ✗ FAILED\n"
  fi
else
  log "  ✗ Tailscale data directory not found"
  FAILED_BACKUPS=$((FAILED_BACKUPS + 1))
  BACKUP_STATUS="${BACKUP_STATUS}Tailscale: ✗ FAILED\n"
fi
log ""
fi

# ============================================
# TRAEFIK - SSL Certificates
# ============================================
if should_backup "traefik"; then
log "Backing up Traefik (SSL certificates)..."
TRAEFIK_SUCCESS=true

if [ -d "$APPS_BASE/front/traefik/acme" ]; then
  TRAEFIK_FILE="$BACKUP_DIR/traefik/acme-${BACKUP_TYPE}-$DATE.tar.gz"
  
  tar -czf "$TRAEFIK_FILE" \
    -C "$APPS_BASE/front/traefik" acme 2>&1 | grep -v "Removing leading" || true
  
  if [ -f "$TRAEFIK_FILE" ]; then
    TRAEFIK_SIZE=$(du -h "$TRAEFIK_FILE" | cut -f1)
    log "  ✓ ACME certificates backed up: acme-${BACKUP_TYPE}-$DATE.tar.gz ($TRAEFIK_SIZE)"
    SUCCESSFUL_BACKUPS=$((SUCCESSFUL_BACKUPS + 1))
    BACKUP_STATUS="${BACKUP_STATUS}Traefik: ✓ SUCCESS\n"
  else
    log "  ✗ Backup failed"
    FAILED_BACKUPS=$((FAILED_BACKUPS + 1))
    BACKUP_STATUS="${BACKUP_STATUS}Traefik: ✗ FAILED\n"
  fi
else
  log "  ⚠ ACME directory not found - skipping"
  BACKUP_STATUS="${BACKUP_STATUS}Traefik: ⚠ SKIPPED\n"
fi
log ""
fi

# ============================================
# PROWLARR - Full Backup
# ============================================
if should_backup "prowlarr"; then
log "Backing up Prowlarr (full backup)..."
PROWLARR_SUCCESS=true

if [ -d "$APPS_BASE/7seas/prowlarr" ]; then
  PROWLARR_FILE="$BACKUP_DIR/prowlarr/full-${BACKUP_TYPE}-$DATE.tar.gz"
  
  tar -czf "$PROWLARR_FILE" \
    --exclude="logs" \
    --exclude="Backups" \
    -C "$APPS_BASE/7seas" prowlarr 2>&1 | grep -v "Removing leading" || true
  
  if [ -f "$PROWLARR_FILE" ]; then
    PROWLARR_SIZE=$(du -h "$PROWLARR_FILE" | cut -f1)
    log "  ✓ Full backup: full-${BACKUP_TYPE}-$DATE.tar.gz ($PROWLARR_SIZE)"
    log "    Includes: databases, config.xml, Definitions"
    SUCCESSFUL_BACKUPS=$((SUCCESSFUL_BACKUPS + 1))
    BACKUP_STATUS="${BACKUP_STATUS}Prowlarr: ✓ SUCCESS\n"
  else
    log "  ✗ Backup failed"
    FAILED_BACKUPS=$((FAILED_BACKUPS + 1))
    BACKUP_STATUS="${BACKUP_STATUS}Prowlarr: ✗ FAILED\n"
  fi
else
  log "  ✗ prowlarr directory not found"
  FAILED_BACKUPS=$((FAILED_BACKUPS + 1))
  BACKUP_STATUS="${BACKUP_STATUS}Prowlarr: ✗ FAILED\n"
fi
log ""
fi

# ============================================
# SONARR - Full Backup
# ============================================
if should_backup "sonarr"; then
log "Backing up Sonarr (full backup)..."
SONARR_SUCCESS=true

if [ -d "$APPS_BASE/7seas/sonarr" ]; then
  SONARR_FILE="$BACKUP_DIR/sonarr/full-${BACKUP_TYPE}-$DATE.tar.gz"
  
  tar -czf "$SONARR_FILE" \
    --exclude="logs" \
    --exclude="Backups" \
    --exclude="MediaCover" \
    -C "$APPS_BASE/7seas" sonarr 2>&1 | grep -v "Removing leading" || true
  
  if [ -f "$SONARR_FILE" ]; then
    SONARR_SIZE=$(du -h "$SONARR_FILE" | cut -f1)
    log "  ✓ Full backup: full-${BACKUP_TYPE}-$DATE.tar.gz ($SONARR_SIZE)"
    log "    Includes: databases, config.xml"
    SUCCESSFUL_BACKUPS=$((SUCCESSFUL_BACKUPS + 1))
    BACKUP_STATUS="${BACKUP_STATUS}Sonarr: ✓ SUCCESS\n"
  else
    log "  ✗ Backup failed"
    FAILED_BACKUPS=$((FAILED_BACKUPS + 1))
    BACKUP_STATUS="${BACKUP_STATUS}Sonarr: ✗ FAILED\n"
  fi
else
  log "  ✗ sonarr directory not found"
  FAILED_BACKUPS=$((FAILED_BACKUPS + 1))
  BACKUP_STATUS="${BACKUP_STATUS}Sonarr: ✗ FAILED\n"
fi
log ""
fi

# ============================================
# RADARR - Full Backup
# ============================================
if should_backup "radarr"; then
log "Backing up Radarr (full backup)..."
RADARR_SUCCESS=true

if [ -d "$APPS_BASE/7seas/radarr" ]; then
  RADARR_FILE="$BACKUP_DIR/radarr/full-${BACKUP_TYPE}-$DATE.tar.gz"
  
  tar -czf "$RADARR_FILE" \
    --exclude="logs" \
    --exclude="Backups" \
    --exclude="MediaCover" \
    -C "$APPS_BASE/7seas" radarr 2>&1 | grep -v "Removing leading" || true
  
  if [ -f "$RADARR_FILE" ]; then
    RADARR_SIZE=$(du -h "$RADARR_FILE" | cut -f1)
    log "  ✓ Full backup: full-${BACKUP_TYPE}-$DATE.tar.gz ($RADARR_SIZE)"
    log "    Includes: databases, config.xml"
    SUCCESSFUL_BACKUPS=$((SUCCESSFUL_BACKUPS + 1))
    BACKUP_STATUS="${BACKUP_STATUS}Radarr: ✓ SUCCESS\n"
  else
    log "  ✗ Backup failed"
    FAILED_BACKUPS=$((FAILED_BACKUPS + 1))
    BACKUP_STATUS="${BACKUP_STATUS}Radarr: ✗ FAILED\n"
  fi
else
  log "  ✗ radarr directory not found"
  FAILED_BACKUPS=$((FAILED_BACKUPS + 1))
  BACKUP_STATUS="${BACKUP_STATUS}Radarr: ✗ FAILED\n"
fi
log ""
fi

# ============================================
# READARR - Full Backup
# ============================================
if should_backup "readarr"; then
log "Backing up Readarr (full backup)..."
READARR_SUCCESS=true

if [ -d "$APPS_BASE/7seas/readarr" ]; then
  READARR_FILE="$BACKUP_DIR/readarr/full-${BACKUP_TYPE}-$DATE.tar.gz"
  
  tar -czf "$READARR_FILE" \
    --exclude="logs" \
    --exclude="Backups" \
    --exclude="MediaCover" \
    -C "$APPS_BASE/7seas" readarr 2>&1 | grep -v "Removing leading" || true
  
  if [ -f "$READARR_FILE" ]; then
    READARR_SIZE=$(du -h "$READARR_FILE" | cut -f1)
    log "  ✓ Full backup: full-${BACKUP_TYPE}-$DATE.tar.gz ($READARR_SIZE)"
    log "    Includes: databases, config.xml"
    SUCCESSFUL_BACKUPS=$((SUCCESSFUL_BACKUPS + 1))
    BACKUP_STATUS="${BACKUP_STATUS}Readarr: ✓ SUCCESS\n"
  else
    log "  ✗ Backup failed"
    FAILED_BACKUPS=$((FAILED_BACKUPS + 1))
    BACKUP_STATUS="${BACKUP_STATUS}Readarr: ✗ FAILED\n"
  fi
else
  log "  ✗ readarr directory not found"
  FAILED_BACKUPS=$((FAILED_BACKUPS + 1))
  BACKUP_STATUS="${BACKUP_STATUS}Readarr: ✗ FAILED\n"
fi
log ""
fi

# ============================================
# ZIGBEE2MQTT - Configuration + Database + Coordinator Backup
# ============================================
if should_backup "zigbee2mqtt"; then
log "Backing up Zigbee2mqtt (config + database + coordinator)..."
Z2M_SUCCESS=true

if [ -d "$APPS_BASE/home/zigbee2mqtt" ]; then
  Z2M_FILE="$BACKUP_DIR/zigbee2mqtt/full-${BACKUP_TYPE}-$DATE.tar.gz"
  
  tar -czf "$Z2M_FILE" \
    --exclude="log" \
    -C "$APPS_BASE/home" zigbee2mqtt 2>&1 | grep -v "Removing leading" || true
  
  if [ -f "$Z2M_FILE" ]; then
    Z2M_SIZE=$(du -h "$Z2M_FILE" | cut -f1)
    log "  ✓ Full backup: full-${BACKUP_TYPE}-$DATE.tar.gz ($Z2M_SIZE)"
    log "    Includes: configuration.yaml, database.db, coordinator_backup.json"
    log "    Critical: Network keys, device pairings, coordinator state"
    SUCCESSFUL_BACKUPS=$((SUCCESSFUL_BACKUPS + 1))
    BACKUP_STATUS="${BACKUP_STATUS}Zigbee2mqtt: ✓ SUCCESS\n"
  else
    log "  ✗ Backup failed"
    FAILED_BACKUPS=$((FAILED_BACKUPS + 1))
    BACKUP_STATUS="${BACKUP_STATUS}Zigbee2mqtt: ✗ FAILED\n"
  fi
else
  log "  ✗ Zigbee2mqtt directory not found"
  FAILED_BACKUPS=$((FAILED_BACKUPS + 1))
  BACKUP_STATUS="${BACKUP_STATUS}Zigbee2mqtt: ✗ FAILED\n"
fi
log ""
fi

# ============================================
# ADGUARD - Configuration + Database
# ============================================
if should_backup "adguard"; then
log "Backing up AdGuard Home (config + database)..."
ADGUARD_SUCCESS=true

if [ -d "$APPS_BASE/network/adguard" ]; then
  ADGUARD_FILE="$BACKUP_DIR/adguard/full-${BACKUP_TYPE}-$DATE.tar.gz"
  
  tar -czf "$ADGUARD_FILE" \
    --exclude="work/data/sessions.db" \
    --exclude="work/data/querylog.json*" \
    -C "$APPS_BASE/network" adguard 2>&1 | grep -v "Removing leading" || true
  
  if [ -f "$ADGUARD_FILE" ]; then
    ADGUARD_SIZE=$(du -h "$ADGUARD_FILE" | cut -f1)
    log "  ✓ Full backup: full-${BACKUP_TYPE}-$DATE.tar.gz ($ADGUARD_SIZE)"
    log "    Includes: AdGuardHome.yaml (config), filters, stats database"
    log "    Excludes: sessions.db, large query logs"
    SUCCESSFUL_BACKUPS=$((SUCCESSFUL_BACKUPS + 1))
    BACKUP_STATUS="${BACKUP_STATUS}AdGuard: ✓ SUCCESS\n"
  else
    log "  ✗ Backup failed"
    FAILED_BACKUPS=$((FAILED_BACKUPS + 1))
    BACKUP_STATUS="${BACKUP_STATUS}AdGuard: ✗ FAILED\n"
  fi
else
  log "  ✗ AdGuard directory not found"
  FAILED_BACKUPS=$((FAILED_BACKUPS + 1))
  BACKUP_STATUS="${BACKUP_STATUS}AdGuard: ✗ FAILED\n"
fi
log ""
fi

# ============================================
# Cleanup Old Backups
# ============================================
log "Cleaning up old backups..."

# Cleanup twice-daily backups (older than 3 days)
# Only delete core backup files (databases, configs, storage) - NOT RSA keys or attachments
log "  Twice-daily backups (>3 days)..."
TWICE_DAILY_BEFORE=$(find "$BACKUP_DIR" -type f \( -name "db-*twice-daily*.sql.gz" -o -name "db-*twice-daily*.sqlite3" -o -name "full-*twice-daily*.tar.gz" -o -name "*twice-daily*.tar.gz" \) | wc -l)
find "$BACKUP_DIR" -type f \( -name "db-*twice-daily*.sql.gz" -o -name "db-*twice-daily*.sqlite3" -o -name "full-*twice-daily*.tar.gz" -o -name "*twice-daily*.tar.gz" \) -mtime +3 -delete 2>&1
TWICE_DAILY_AFTER=$(find "$BACKUP_DIR" -type f \( -name "db-*twice-daily*.sql.gz" -o -name "db-*twice-daily*.sqlite3" -o -name "full-*twice-daily*.tar.gz" -o -name "*twice-daily*.tar.gz" \) | wc -l)
log "    Deleted $((TWICE_DAILY_BEFORE - TWICE_DAILY_AFTER)) twice-daily backups, $TWICE_DAILY_AFTER remaining"

# Cleanup daily backups (older than 7 days)
log "  Daily backups (>7 days)..."
DAILY_BEFORE=$(find "$BACKUP_DIR" -type f \( -name "db-*daily*.sql.gz" -o -name "db-*daily*.sqlite3" -o -name "full-*daily*.tar.gz" -o -name "*daily*.tar.gz" \) ! -name "*twice-daily*" | wc -l)
find "$BACKUP_DIR" -type f \( -name "db-*daily*.sql.gz" -o -name "db-*daily*.sqlite3" -o -name "full-*daily*.tar.gz" -o -name "*daily*.tar.gz" \) ! -name "*twice-daily*" -mtime +7 -delete 2>&1
DAILY_AFTER=$(find "$BACKUP_DIR" -type f \( -name "db-*daily*.sql.gz" -o -name "db-*daily*.sqlite3" -o -name "full-*daily*.tar.gz" -o -name "*daily*.tar.gz" \) ! -name "*twice-daily*" | wc -l)
log "    Deleted $((DAILY_BEFORE - DAILY_AFTER)) daily backups, $DAILY_AFTER remaining"

# Cleanup weekly backups (older than 28 days / 4 weeks)
log "  Weekly backups (>28 days)..."
WEEKLY_BEFORE=$(find "$BACKUP_DIR" -type f \( -name "db-*weekly*.sql.gz" -o -name "db-*weekly*.sqlite3" -o -name "full-*weekly*.tar.gz" -o -name "*weekly*.tar.gz" \) | wc -l)
find "$BACKUP_DIR" -type f \( -name "db-*weekly*.sql.gz" -o -name "db-*weekly*.sqlite3" -o -name "full-*weekly*.tar.gz" -o -name "*weekly*.tar.gz" \) -mtime +28 -delete 2>&1
WEEKLY_AFTER=$(find "$BACKUP_DIR" -type f \( -name "db-*weekly*.sql.gz" -o -name "db-*weekly*.sqlite3" -o -name "full-*weekly*.tar.gz" -o -name "*weekly*.tar.gz" \) | wc -l)
log "    Deleted $((WEEKLY_BEFORE - WEEKLY_AFTER)) weekly backups, $WEEKLY_AFTER remaining"

# Cleanup monthly backups (older than 180 days / 6 months)
log "  Monthly backups (>180 days)..."
MONTHLY_BEFORE=$(find "$BACKUP_DIR" -type f \( -name "db-*monthly*.sql.gz" -o -name "db-*monthly*.sqlite3" -o -name "full-*monthly*.tar.gz" -o -name "*monthly*.tar.gz" \) | wc -l)
find "$BACKUP_DIR" -type f \( -name "db-*monthly*.sql.gz" -o -name "db-*monthly*.sqlite3" -o -name "full-*monthly*.tar.gz" -o -name "*monthly*.tar.gz" \) -mtime +180 -delete 2>&1
MONTHLY_AFTER=$(find "$BACKUP_DIR" -type f \( -name "db-*monthly*.sql.gz" -o -name "db-*monthly*.sqlite3" -o -name "full-*monthly*.tar.gz" -o -name "*monthly*.tar.gz" \) | wc -l)
log "    Deleted $((MONTHLY_BEFORE - MONTHLY_AFTER)) monthly backups, $MONTHLY_AFTER remaining"

# Cleanup orphaned Vaultwarden files (no matching database backup)
log "  Cleaning up orphaned Vaultwarden RSA keys and attachments..."
ORPHANED_COUNT=0
for backup_type in twice-daily daily weekly monthly; do
  for file in "$BACKUP_DIR"/vaultwarden/rsa_key-${backup_type}-*.pem "$BACKUP_DIR"/vaultwarden/attachments-${backup_type}-*.tar.gz; do
    if [ -f "$file" ]; then
      timestamp=$(basename "$file" | grep -oE '[0-9]{8}-[0-9]{4}')
      if [ ! -f "$BACKUP_DIR/vaultwarden/db-${backup_type}-${timestamp}.sqlite3" ]; then
        rm -f "$file"
        ORPHANED_COUNT=$((ORPHANED_COUNT + 1))
      fi
    fi
  done
done
log "    Deleted $ORPHANED_COUNT orphaned files"

# Total count
TOTAL_BACKUPS=$(find "$BACKUP_DIR" -type f | wc -l)
log "  Total backup files: $TOTAL_BACKUPS"
log ""

# ============================================
# Summary
# ============================================
log "=========================================="
log "=== Backup Summary ==="
log "=========================================="
log "Backup location: $BACKUP_DIR"
log ""
log "Status by service:"
echo -e "$BACKUP_STATUS" | tee -a "$LOG_FILE"
log "Results: $SUCCESSFUL_BACKUPS successful, $FAILED_BACKUPS failed (out of $TOTAL_SERVICES)"
log ""
log "Disk usage by service:"
du -sh "$BACKUP_DIR"/* 2>/dev/null | tee -a "$LOG_FILE"
log ""
log "Total backup size:"
du -sh "$BACKUP_DIR" 2>/dev/null | tee -a "$LOG_FILE"
log ""
log "Completed at: $(date)"
log "=========================================="
log ""

# Ensure backup files are owned by max:homelab
chown -R max:homelab "$BACKUP_DIR" 2>/dev/null || true

# Exit with error code if any backups failed
if [ $FAILED_BACKUPS -gt 0 ]; then
  exit 1
else
  exit 0
fi
