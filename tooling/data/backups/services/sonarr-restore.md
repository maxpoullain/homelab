# Sonarr Restore Guide

This guide explains how to restore Sonarr from backups located in `/mnt/tank/backups/homelab/sonarr/`.

## Backup Files

- `full-[type]-[date].tar.gz` - Complete Sonarr backup (databases + config)

## What's Included

- **Databases**: sonarr.db (main), logs.db (logs)
- **Configuration**: config.xml (settings, API keys, auth)
- **Settings**: All series, download clients, indexers, quality profiles

## What's Excluded

- **Logs**: Log files directory
- **Backups**: Built-in Backups folder
- **MediaCover**: Cached poster/banner images (regenerable)

## Quick Restore

### 1. Stop Sonarr

```bash
cd /mnt/fast/apps/homelab/media
docker compose stop sonarr
```

### 2. Backup Current Config (Optional but Recommended)

```bash
sudo mv /mnt/fast/apps/homelab/media/sonarr \
   /mnt/fast/apps/homelab/media/sonarr.backup.$(date +%Y%m%d-%H%M)
```

### 3. Restore Full Backup

```bash
# Choose your backup file
BACKUP_FILE="/mnt/tank/backups/homelab/sonarr/full-daily-20251104-1900.tar.gz"

# Create directory
sudo mkdir -p /mnt/fast/apps/homelab/media/

# Extract backup
sudo tar -xzf "$BACKUP_FILE" -C /mnt/fast/apps/homelab/media/

# Fix permissions
sudo chown -R max:homelab /mnt/fast/apps/homelab/media/sonarr
```

### 4. Start Sonarr

```bash
cd /mnt/fast/apps/homelab/media
docker compose up -d sonarr
```

### 5. Verify Restore

```bash
# Check logs
docker logs sonarr -f

# Access web UI
# Navigate to https://sonarr.yourdomain.com

# Verify:
# - Series are listed
# - Download clients are configured
# - Indexers are connected
# - Quality profiles exist
# - Episode history is preserved
```

## Verify Backup Before Restore

```bash
# List contents of backup
tar -tzf /mnt/tank/backups/homelab/sonarr/full-daily-20251104-1900.tar.gz | head -20

# Should show:
# sonarr/sonarr.db
# sonarr/logs.db
# sonarr/config.xml
```

## Restore to New System

```bash
# 1. Create directory structure
sudo mkdir -p /mnt/fast/apps/homelab/media/

# 2. Choose backup file
BACKUP_FILE="/mnt/tank/backups/homelab/sonarr/full-daily-20251104-1900.tar.gz"

# 3. Extract backup
sudo tar -xzf "$BACKUP_FILE" -C /mnt/fast/apps/homelab/media/

# 4. Fix ownership
sudo chown -R max:homelab /mnt/fast/apps/homelab/media/sonarr

# 5. Start Sonarr
cd /mnt/fast/apps/homelab/media
docker compose up -d sonarr
```

## Common Issues

### Permission Errors

```bash
# Fix ownership
sudo chown -R max:homelab /mnt/fast/apps/homelab/media/sonarr
```

### List Available Backups

```bash
# List all Sonarr backups
ls -lht /mnt/tank/backups/homelab/sonarr/

# Find most recent backup
ls -lt /mnt/tank/backups/homelab/sonarr/ | head -5
```

## Backup Types

| Type | Retention | When Created |
|------|-----------|--------------|
| twice-daily | 3 days | 7 AM, 7 PM |
| daily | 7 days | 7 PM |
| weekly | 28 days | Sunday 7 PM |
| monthly | 180 days | 1st of month, 7 PM |

## Notes

- **Backup method**: Full directory backup (like Jellyfin)
- **Safe while running**: Backups taken while Sonarr is running
- **All-in-one**: Single tar.gz file contains everything
- **Simple restore**: Just extract and set permissions
