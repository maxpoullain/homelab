# Jellyfin Restore Guide

This guide explains how to restore Jellyfin from backups located in `/mnt/tank/backups/homelab/jellyfin/`.

## Backup Files

- `full-[type]-[date].tar.gz` - Complete Jellyfin backup (databases + config + metadata + plugins)

## What's Included

- **Databases**: jellyfin.db (main), authentication.db (users)
- **Metadata**: Movie/TV show metadata, posters, fanart
- **Plugins**: Installed plugins and their configurations
- **Settings**: Server configuration, library settings, transcoding profiles
- **Users**: User accounts, watch history, preferences

## What's Excluded

- **Cache**: Regenerable cache data
- **Logs**: Log files
- **Transcodes**: Temporary transcoding files

## Quick Restore

### 1. Stop Jellyfin

```bash
cd /mnt/fast/apps/homelab/tv
docker compose down
```

### 2. Backup Current Config (Optional but Recommended)

```bash
mv /mnt/fast/apps/homelab/tv/jellyfin/config \
   /mnt/fast/apps/homelab/tv/jellyfin/config.backup.$(date +%Y%m%d)
```

### 3. Restore Full Backup

```bash
# Choose your backup file
BACKUP_FILE="/mnt/tank/backups/homelab/jellyfin/full-daily-20251025-2236.tar.gz"

# Extract to Jellyfin directory
tar -xzf "$BACKUP_FILE" -C /mnt/fast/apps/homelab/tv/jellyfin/

# Fix permissions
sudo chown -R 1000:1000 /mnt/fast/apps/homelab/tv/jellyfin/config/
```

### 4. Start Jellyfin

```bash
cd /mnt/fast/apps/homelab/tv
docker compose up -d
```

### 5. Verify Restore

```bash
# Check logs
docker logs jellyfin

# Access web UI
# Navigate to https://jellyfin.yourdomain.com

# Verify:
# - Users can log in
# - Libraries are visible
# - Watch history is preserved
# - Plugins are loaded
```

## Verify Backup Before Restore

```bash
# List contents of backup
tar -tzf /mnt/tank/backups/homelab/jellyfin/full-daily-20251025-2236.tar.gz | head -20

# Check backup size (should be several MB)
ls -lh /mnt/tank/backups/homelab/jellyfin/full-daily-20251025-2236.tar.gz

# Extract to temporary location for inspection (optional)
mkdir /tmp/jellyfin-test
tar -xzf /mnt/tank/backups/homelab/jellyfin/full-daily-20251025-2236.tar.gz -C /tmp/jellyfin-test/
ls -lah /tmp/jellyfin-test/config/data/data/*.db
```

## Partial Restore

### Extract Specific Files

If you only need specific files (e.g., just the databases):

```bash
# Extract only databases
tar -xzf /mnt/tank/backups/homelab/jellyfin/full-daily-20251025-2236.tar.gz \
  -C /tmp/ \
  config/data/data/jellyfin.db \
  config/data/data/authentication.db

# Copy to Jellyfin directory
cp /tmp/config/data/data/*.db /mnt/fast/apps/homelab/tv/jellyfin/config/data/data/
sudo chown 1000:1000 /mnt/fast/apps/homelab/tv/jellyfin/config/data/data/*.db
```

### Restore Configuration Only (No Databases)

```bash
# Extract everything except databases
tar -xzf /mnt/tank/backups/homelab/jellyfin/full-daily-20251025-2236.tar.gz \
  -C /mnt/fast/apps/homelab/tv/jellyfin/ \
  --exclude="config/data/data/*.db"
```

## Disaster Recovery

To restore Jellyfin on a new server:

1. Install Docker and Docker Compose
2. Copy compose.yml from `/mnt/fast/apps/homelab/tv/`
3. Ensure media files are accessible at the same paths
4. Restore full backup before first start
5. Start Jellyfin
6. Update DNS/reverse proxy
7. Verify library paths in Settings → Libraries

## Troubleshooting

### Jellyfin starts but libraries are empty

**Cause**: Media file paths have changed

**Solution**:
1. Go to Settings → Libraries
2. Edit each library
3. Update folder paths to match new server
4. Click "Scan Library"

### "Database is locked" error

```bash
# Stop Jellyfin
docker compose down

# Verify no processes are using the database
lsof /mnt/fast/apps/homelab/tv/jellyfin/config/data/data/jellyfin.db

# Restore again
tar -xzf "$BACKUP_FILE" -C /mnt/fast/apps/homelab/tv/jellyfin/
```

### Users can't log in after restore

Check authentication database was restored:

```bash
ls -lh /mnt/fast/apps/homelab/tv/jellyfin/config/data/data/authentication.db

# If missing, extract it specifically
tar -xzf /mnt/tank/backups/homelab/jellyfin/full-daily-20251025-2236.tar.gz \
  -C /tmp/ \
  config/data/data/authentication.db

cp /tmp/config/data/data/authentication.db \
   /mnt/fast/apps/homelab/tv/jellyfin/config/data/data/
```

### Plugins missing after restore

```bash
# Check plugins directory was restored
ls -lah /mnt/fast/apps/homelab/tv/jellyfin/config/plugins/

# If empty, extract plugins specifically
tar -xzf /mnt/tank/backups/homelab/jellyfin/full-daily-20251025-2236.tar.gz \
  -C /mnt/fast/apps/homelab/tv/jellyfin/ \
  config/plugins/
```

### Permission errors

```bash
# Fix all permissions
sudo chown -R 1000:1000 /mnt/fast/apps/homelab/tv/jellyfin/config/
sudo chmod -R 755 /mnt/fast/apps/homelab/tv/jellyfin/config/
```

## Important Notes

- **Full backup method**: Uses tar to backup entire config directory (databases + everything else)
- **No Python/sqlite3**: Jellyfin container doesn't have SQLite tools, so we backup everything together
- **Simpler approach**: One archive contains everything needed for complete restore
- **Watch history preserved**: User watch history is in the main database
- **Plugin configs preserved**: All plugin settings are included
- **Media files separate**: Media files themselves are NOT in this backup (too large)
- **Transcoding profiles**: Server transcoding settings are preserved

## Restoring to Different Server

When restoring to a server with different paths:

1. Restore the full backup
2. Start Jellyfin
3. Go to Settings → Dashboard → Libraries
4. For each library, edit and update the folder paths
5. Click "Scan All Libraries"

The metadata will be preserved even if paths change.
