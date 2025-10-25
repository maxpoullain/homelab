# Immich Restore Guide

This guide explains how to restore Immich from backups located in `/mnt/tank/backups/homelab/immich/`.

## Backup Files

- `db-[type]-[date].sql.gz` - PostgreSQL database (all databases + roles)
- `storage-[type]-[date].tar.gz` - Original photos/videos (library, upload, profile)

## Quick Restore

### 1. Stop Immich Services

```bash
cd /mnt/fast/apps/homelab/immich
docker compose down
```

### 2. Restore Database

```bash
# Choose your backup file
BACKUP_FILE="/mnt/tank/backups/homelab/immich/db-daily-20251025-2236.sql.gz"

# Restore to PostgreSQL
gunzip -c "$BACKUP_FILE" | docker exec -i immich_postgres psql -U postgres

# Or if container is not running, start it first:
docker compose up -d immich_postgres
sleep 5
gunzip -c "$BACKUP_FILE" | docker exec -i immich_postgres psql -U postgres
```

### 3. Restore Storage Files

```bash
# Choose your storage backup
STORAGE_BACKUP="/mnt/tank/backups/homelab/immich/storage-daily-20251025-2236.tar.gz"

# Extract to storage directory
tar -xzf "$STORAGE_BACKUP" -C /mnt/fast/apps/homelab/immich/storage/

# Fix permissions
sudo chown -R 1000:1000 /mnt/fast/apps/homelab/immich/storage/
```

### 4. Start All Services

```bash
cd /mnt/fast/apps/homelab/immich
docker compose up -d
```

### 5. Regenerate Thumbnails (if needed)

If you only restored library/upload/profile (not thumbs/encoded-video):

1. Go to Immich web UI → Administration → Jobs
2. Run **"Generate Thumbnails"** job
3. Run **"Transcode Videos"** job (if you use transcoding)

## Verify Restore

```bash
# Check database is accessible
docker exec -it immich_postgres psql -U postgres -c "\l"

# Check storage files exist
ls -lah /mnt/fast/apps/homelab/immich/storage/library/
ls -lah /mnt/fast/apps/homelab/immich/storage/upload/

# Check Immich logs
docker logs immich_server
```

## Partial Restore

### Database Only

If you only need to restore the database (keeping existing storage):

```bash
gunzip -c /mnt/tank/backups/homelab/immich/db-daily-20251025-2236.sql.gz | \
  docker exec -i immich_postgres psql -U postgres
```

### Storage Only

If you only need to restore photos/videos (keeping existing database):

```bash
tar -xzf /mnt/tank/backups/homelab/immich/storage-daily-20251025-2236.tar.gz \
  -C /mnt/fast/apps/homelab/immich/storage/
sudo chown -R 1000:1000 /mnt/fast/apps/homelab/immich/storage/
```

## Troubleshooting

### Database restore fails with "already exists" errors

The `--clean` flag in backups should handle this, but if it fails:

```bash
# Drop and recreate database
docker exec -it immich_postgres psql -U postgres
DROP DATABASE immich;
CREATE DATABASE immich;
\q

# Then restore
gunzip -c "$BACKUP_FILE" | docker exec -i immich_postgres psql -U postgres
```

### Permission denied errors

```bash
# Fix storage permissions
sudo chown -R 1000:1000 /mnt/fast/apps/homelab/immich/storage/
sudo chmod -R 755 /mnt/fast/apps/homelab/immich/storage/
```

### Missing thumbnails after restore

This is expected - thumbnails are not backed up (29GB, regenerable).

Regenerate via: Admin → Jobs → "Generate Thumbnails"

## Notes

- **Thumbnails excluded**: The `thumbs/` directory (29GB) is not backed up as it can be regenerated
- **Encoded video excluded**: The `encoded-video/` directory (1.3GB) is not backed up as it can be regenerated
- **Database includes roles**: The backup includes all PostgreSQL users and permissions
- **Backup is consistent**: Database and storage backups are from the same backup run
