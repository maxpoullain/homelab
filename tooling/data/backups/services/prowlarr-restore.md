# Prowlarr Restore Guide

This guide explains how to restore Prowlarr from backups located in `/mnt/tank/backups/homelab/prowlarr/`.

## Backup Files

- `full-[type]-[date].tar.gz` - Complete Prowlarr backup (databases + config + definitions)

## What's Included

- **Databases**: prowlarr.db (main), logs.db (logs)
- **Configuration**: config.xml (settings, API keys, auth)
- **Definitions**: Indexer definitions
- **Settings**: All indexer configurations, applications, download clients

## What's Excluded

- **Logs**: Log files directory
- **Backups**: Built-in Backups folder
- **Temporary files**: Cache and temp data

## Quick Restore

### 1. Stop Prowlarr

```bash
cd /mnt/fast/apps/homelab/media
docker compose stop prowlarr
```

### 2. Backup Current Config (Optional but Recommended)

```bash
sudo mv /mnt/fast/apps/homelab/media/prowlarr \
   /mnt/fast/apps/homelab/media/prowlarr.backup.$(date +%Y%m%d-%H%M)
```

### 3. Restore Full Backup

```bash
# Choose your backup file
BACKUP_FILE="/mnt/tank/backups/homelab/prowlarr/full-daily-20251104-1900.tar.gz"

# Create directory
sudo mkdir -p /mnt/fast/apps/homelab/media/

# Extract backup
sudo tar -xzf "$BACKUP_FILE" -C /mnt/fast/apps/homelab/media/

# Fix permissions
sudo chown -R max:homelab /mnt/fast/apps/homelab/media/prowlarr
```

### 4. Start Prowlarr

```bash
cd /mnt/fast/apps/homelab/media
docker compose up -d prowlarr
```

### 5. Verify Restore

```bash
# Check logs
docker logs prowlarr -f

# Access web UI
# Navigate to https://prowlarr.yourdomain.com

# Verify:
# - Indexers are configured
# - Applications (Sonarr, Radarr, etc.) are connected
# - Download clients are configured
# - Recent history is visible
```

## Verify Backup Before Restore

```bash
# List contents of backup
tar -tzf /mnt/tank/backups/homelab/prowlarr/full-daily-20251104-1900.tar.gz | head -20

# Should show:
# prowlarr/prowlarr.db
# prowlarr/logs.db
# prowlarr/config.xml
# prowlarr/Definitions/
```

## Restore to New System

```bash
# 1. Create directory structure
sudo mkdir -p /mnt/fast/apps/homelab/media/

# 2. Choose backup file
BACKUP_FILE="/mnt/tank/backups/homelab/prowlarr/full-daily-20251104-1900.tar.gz"

# 3. Extract backup
sudo tar -xzf "$BACKUP_FILE" -C /mnt/fast/apps/homelab/media/

# 4. Fix ownership
sudo chown -R max:homelab /mnt/fast/apps/homelab/media/prowlarr

# 5. Start Prowlarr
cd /mnt/fast/apps/homelab/media
docker compose up -d prowlarr
```

## Database Integrity Check

```bash
# Check container is running
docker ps | grep prowlarr

# Check file sizes
ls -lh /mnt/fast/apps/homelab/media/prowlarr/*.db
```

## Common Issues

### Permission Errors

```bash
# Fix ownership
sudo chown -R max:homelab /mnt/fast/apps/homelab/media/prowlarr
```

### List Available Backups

```bash
# List all Prowlarr backups
ls -lht /mnt/tank/backups/homelab/prowlarr/

# Find most recent backup
ls -lt /mnt/tank/backups/homelab/prowlarr/ | head -5
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
- **Safe while running**: Backups taken while Prowlarr is running
- **All-in-one**: Single tar.gz file contains everything
- **Simple restore**: Just extract and set permissions

