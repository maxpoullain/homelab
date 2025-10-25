# OtterWiki Restore Guide

This guide explains how to restore OtterWiki from backups located in `/mnt/tank/backups/homelab/wiki/`.

## Backup Files

- `db-[type]-[date].sqlite3` - Complete wiki database (all pages, history, users)

## Quick Restore

### 1. Stop OtterWiki

```bash
cd /mnt/fast/apps/homelab/wiki
docker compose down
```

### 2. Restore Database

```bash
# Choose your backup file
BACKUP_FILE="/mnt/tank/backups/homelab/wiki/db-daily-20251025-2236.sqlite3"

# Copy to OtterWiki data directory
cp "$BACKUP_FILE" /mnt/fast/apps/homelab/wiki/otter/repository/db.sqlite

# Fix permissions
sudo chown 1000:1000 /mnt/fast/apps/homelab/wiki/otter/repository/db.sqlite
```

### 3. Start OtterWiki

```bash
cd /mnt/fast/apps/homelab/wiki
docker compose up -d
```

### 4. Verify Restore

```bash
# Check logs
docker logs otterwiki

# Access web UI
# Navigate to https://wiki.yourdomain.com

# Verify pages and history are accessible
```

## Verify Backup Before Restore

```bash
# Check database integrity
sqlite3 /mnt/tank/backups/homelab/wiki/db-daily-20251025-2236.sqlite3 "PRAGMA integrity_check;"

# Should output: ok

# Check database size (should be > 0)
ls -lh /mnt/tank/backups/homelab/wiki/db-daily-20251025-2236.sqlite3
```

## Advanced: Selective Restore

### Export Specific Pages

If you only need to recover specific pages:

```bash
# Open the backup database
sqlite3 /mnt/tank/backups/homelab/wiki/db-daily-20251025-2236.sqlite3

# List all pages
SELECT title FROM pages;

# Export specific page content
SELECT content FROM pages WHERE title='YourPageName';
```

### Merge with Existing Database

If you want to restore specific pages without losing current data, you'll need to:

1. Export pages from backup database (SQL)
2. Import them into current database
3. This is advanced - consider using OtterWiki's export/import features instead

## Troubleshooting

### "Database is locked" error

```bash
# Stop OtterWiki first
cd /mnt/fast/apps/homelab/wiki
docker compose down

# Then restore
cp /mnt/tank/backups/homelab/wiki/db-daily-20251025-2236.sqlite3 \
   /mnt/fast/apps/homelab/wiki/otter/repository/db.sqlite

# Start again
docker compose up -d
```

### Permission denied errors

```bash
sudo chown 1000:1000 /mnt/fast/apps/homelab/wiki/otter/repository/db.sqlite
sudo chmod 644 /mnt/fast/apps/homelab/wiki/otter/repository/db.sqlite
```

### Backup appears empty or corrupted

```bash
# Verify backup file
file /mnt/tank/backups/homelab/wiki/db-daily-20251025-2236.sqlite3
# Should say: SQLite 3.x database

# Check integrity
sqlite3 /mnt/tank/backups/homelab/wiki/db-daily-20251025-2236.sqlite3 "PRAGMA integrity_check;"

# If corrupted, try an older backup
ls -lth /mnt/tank/backups/homelab/wiki/
```

## Disaster Recovery

To restore OtterWiki on a new server:

1. Install Docker and Docker Compose
2. Copy compose.yml from `/mnt/fast/apps/homelab/wiki/`
3. Create directory structure:
   ```bash
   mkdir -p /mnt/fast/apps/homelab/wiki/otter/repository
   ```
4. Restore database before first start
5. Start OtterWiki
6. Update DNS/reverse proxy

## Notes

- **Backup Method**: Uses Python's SQLite Online Backup API (safe while wiki is running)
- **No WAL files needed**: Backup is a complete standalone database
- **Size**: Typically very small (under 1MB for most wikis)
- **Frequency**: Daily backups retained for 7 days, weekly for 28 days, monthly for 180 days
