#!/bin/bash
# Comprehensive TrueNAS Configuration Backup

BACKUP_DIR="/mnt/tank/backups/truenas"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$SCRIPT_DIR/backup-truenas.log"
DATE=$(date +%Y%m%d-%H%M)
DAY_OF_WEEK=$(date +%u)  # 1-7 (Monday-Sunday)
DAY_OF_MONTH=$(date +%d)

# Rotate log file if it's larger than 10MB
if [ -f "$LOG_FILE" ] && [ $(stat -f%z "$LOG_FILE" 2>/dev/null || stat -c%s "$LOG_FILE" 2>/dev/null) -gt 10485760 ]; then
  mv "$LOG_FILE" "$LOG_FILE.old"
  rm -f "$LOG_FILE.old.old" 2>/dev/null
fi

# Logging function
log() {
  echo "$1" | tee -a "$LOG_FILE"
}

# Determine backup type based on date
if [ "$DAY_OF_MONTH" = "01" ]; then
  BACKUP_TYPE="monthly"
elif [ "$DAY_OF_WEEK" = "7" ]; then
  BACKUP_TYPE="weekly"
else
  BACKUP_TYPE="daily"
fi

mkdir -p "$BACKUP_DIR"

# Create backup folder for this run
BACKUP_FOLDER="$BACKUP_DIR/${BACKUP_TYPE}-$DATE"
mkdir -p "$BACKUP_FOLDER"

log ""
log "=========================================="
log "=== TrueNAS Configuration Backup ==="
log "Date: $(date)"
log "Backup type: $BACKUP_TYPE"
log "Backup folder: $BACKUP_FOLDER"
log "=========================================="
log ""

# 1. System configuration
log "Backing up system configuration..."
if midclt call system.config_upload | base64 -d > "$BACKUP_FOLDER/truenas-config.tar" 2>&1 | tee -a "$LOG_FILE"; then
  gzip "$BACKUP_FOLDER/truenas-config.tar"
  CONFIG_SIZE=$(du -h "$BACKUP_FOLDER/truenas-config.tar.gz" | cut -f1)
  log "  ✓ System config backed up ($CONFIG_SIZE)"
else
  log "  ✗ System config backup failed"
fi

# 2. SSH keys
log "Backing up SSH keys..."
if tar -czf "$BACKUP_FOLDER/ssh-keys.tar.gz" /etc/ssh/ssh_host_* 2>/dev/null; then
  SSH_SIZE=$(du -h "$BACKUP_FOLDER/ssh-keys.tar.gz" | cut -f1)
  log "  ✓ SSH keys backed up ($SSH_SIZE)"
else
  log "  ✗ SSH keys backup failed"
fi

# 3. SSL certificates
log "Backing up SSL certificates..."
if tar -czf "$BACKUP_FOLDER/ssl-certs.tar.gz" /etc/certificates 2>/dev/null; then
  SSL_SIZE=$(du -h "$BACKUP_FOLDER/ssl-certs.tar.gz" | cut -f1)
  log "  ✓ SSL certificates backed up ($SSL_SIZE)"
else
  log "  ⚠ SSL certificates backup failed (may not exist)"
fi

# 4. ZFS configuration
log "Backing up ZFS configuration..."
cat > "$BACKUP_FOLDER/zfs-config.txt" << EOF
=== ZFS Pool Status ===
$(zpool status)

=== ZFS Pool List ===
$(zpool list -v)

=== ZFS Properties ===
$(zfs get all)
EOF
ZFS_SIZE=$(du -h "$BACKUP_FOLDER/zfs-config.txt" | cut -f1)
log "  ✓ ZFS config backed up ($ZFS_SIZE)"

# 5. Network configuration
log "Backing up network configuration..."
cat > "$BACKUP_FOLDER/network.txt" << EOF
=== IP Addresses ===
$(ip addr)

=== Netplan Configuration ===
$(cat /etc/netplan/*.yaml 2>/dev/null)
EOF
NET_SIZE=$(du -h "$BACKUP_FOLDER/network.txt" | cut -f1)
log "  ✓ Network config backed up ($NET_SIZE)"

# 6. Cron jobs (from middleware)
log "Backing up cron jobs..."
if midclt call cronjob.query > "$BACKUP_FOLDER/cronjobs.json" 2>&1 | tee -a "$LOG_FILE"; then
  CRON_SIZE=$(du -h "$BACKUP_FOLDER/cronjobs.json" | cut -f1)
  log "  ✓ Cron jobs backed up ($CRON_SIZE)"
else
  log "  ✗ Cron jobs backup failed"
fi

# Cleanup old backups by type
log ""
log "Cleaning up old backups..."

# Daily backups: keep 7 days
DAILY_BEFORE=$(find "$BACKUP_DIR" -type d -name "daily-*" | wc -l)
find "$BACKUP_DIR" -type d -name "daily-*" -mtime +7 -exec rm -rf {} \; 2>/dev/null
DAILY_AFTER=$(find "$BACKUP_DIR" -type d -name "daily-*" | wc -l)
log "  Daily backups: deleted $((DAILY_BEFORE - DAILY_AFTER)), $DAILY_AFTER remaining"

# Weekly backups: keep 4 weeks (28 days)
WEEKLY_BEFORE=$(find "$BACKUP_DIR" -type d -name "weekly-*" | wc -l)
find "$BACKUP_DIR" -type d -name "weekly-*" -mtime +28 -exec rm -rf {} \; 2>/dev/null
WEEKLY_AFTER=$(find "$BACKUP_DIR" -type d -name "weekly-*" | wc -l)
log "  Weekly backups: deleted $((WEEKLY_BEFORE - WEEKLY_AFTER)), $WEEKLY_AFTER remaining"

# Monthly backups: keep 3 months (90 days)
MONTHLY_BEFORE=$(find "$BACKUP_DIR" -type d -name "monthly-*" | wc -l)
find "$BACKUP_DIR" -type d -name "monthly-*" -mtime +90 -exec rm -rf {} \; 2>/dev/null
MONTHLY_AFTER=$(find "$BACKUP_DIR" -type d -name "monthly-*" | wc -l)
log "  Monthly backups: deleted $((MONTHLY_BEFORE - MONTHLY_AFTER)), $MONTHLY_AFTER remaining"

TOTAL_DIRS=$(find "$BACKUP_DIR" -mindepth 1 -maxdepth 1 -type d | wc -l)
TOTAL_SIZE=$(du -sh "$BACKUP_DIR" | cut -f1)

log ""
log "=========================================="
log "=== Backup Summary ==="
log "=========================================="
log "Backup type: $BACKUP_TYPE"
log "Backup folder: $BACKUP_FOLDER"
log "Total backup folders: $TOTAL_DIRS"
log "Total size: $TOTAL_SIZE"
log ""
log "Backup contents:"
ls -lh "$BACKUP_FOLDER" | tee -a "$LOG_FILE"
log ""
log "Recent backup folders:"
ls -lhdt "$BACKUP_DIR"/*/ | head -5 | tee -a "$LOG_FILE"
log ""
log "Completed at: $(date)"
log "=========================================="
log ""
