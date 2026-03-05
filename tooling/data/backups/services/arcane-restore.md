# Arcane Restore Guide

Restore Arcane (Docker management dashboard) SQLite database.

## What's Backed Up

- **db-[type]-[date].sqlite3** - Arcane SQLite database (stacks, deployment history, upgrade logs, settings)

**Not backed up (not needed):**
- Stack compose files and configs are read directly from `/mnt/fast/apps/homelab` at runtime (mounted read-only)
- No persistent state beyond the database itself

## Backup Location

```
/mnt/tank/backups/homelab/arcane/
├── db-twice-daily-20251113-0700.sqlite3
├── db-daily-20251112-1900.sqlite3
├── db-weekly-20251110-1900.sqlite3
└── db-monthly-20251101-1900.sqlite3
```

## Quick Restore

### 1. Stop Arcane

```bash
cd /mnt/fast/apps/homelab/admin
docker compose stop arcane
```

### 2. Backup Current Database (Optional but Recommended)

```bash
cp /mnt/fast/apps/homelab/corsair/admin/arcane/arcane.db \
   /mnt/fast/apps/homelab/corsair/admin/arcane/arcane.db.backup.$(date +%Y%m%d-%H%M)
```

### 3. Restore Database

```bash
# Choose your backup file
BACKUP_FILE="/mnt/tank/backups/homelab/arcane/db-daily-20251104-1900.sqlite3"

# Copy database into place
cp "$BACKUP_FILE" /mnt/fast/apps/homelab/corsair/admin/arcane/arcane.db

# Remove any stale WAL/SHM files to avoid conflicts
rm -f /mnt/fast/apps/homelab/corsair/admin/arcane/arcane.db-shm
rm -f /mnt/fast/apps/homelab/corsair/admin/arcane/arcane.db-wal

# Fix permissions (Arcane runs as PUID=3000 / PGID=3002)
sudo chown 3000:3002 /mnt/fast/apps/homelab/corsair/admin/arcane/arcane.db
```

### 4. Start Arcane

```bash
cd /mnt/fast/apps/homelab/admin
docker compose up -d arcane
```

### 5. Verify Restore

```bash
# Check logs
docker logs arcane -f

# Access web UI
# Navigate to https://docker.corsair.tf

# Verify:
# - All stacks are visible
# - Deployment history is present
# - Settings are intact
```

## What to Expect After Restore

- ✅ Stack list and metadata restored
- ✅ Deployment and upgrade history restored
- ✅ Application settings and preferences restored
- ✅ Live container state is read directly from Docker — always current regardless of restore

## Verify Backup Before Restore

```bash
# Check SQLite integrity
sqlite3 /mnt/tank/backups/homelab/arcane/db-daily-20251104-1900.sqlite3 \
  "PRAGMA integrity_check;"

# Should output: ok

# Inspect table list
sqlite3 /mnt/tank/backups/homelab/arcane/db-daily-20251104-1900.sqlite3 \
  ".tables"
```

## Restore to New System

```bash
# 1. Create directory structure
sudo mkdir -p /mnt/fast/apps/homelab/corsair/admin/arcane/templates

# 2. Choose backup file
BACKUP_FILE="/mnt/tank/backups/homelab/arcane/db-daily-20251104-1900.sqlite3"

# 3. Copy database into place
cp "$BACKUP_FILE" /mnt/fast/apps/homelab/corsair/admin/arcane/arcane.db

# 4. Remove stale WAL/SHM if present
rm -f /mnt/fast/apps/homelab/corsair/admin/arcane/arcane.db-shm
rm -f /mnt/fast/apps/homelab/corsair/admin/arcane/arcane.db-wal

# 5. Fix ownership
sudo chown 3000:3002 /mnt/fast/apps/homelab/corsair/admin/arcane/arcane.db

# 6. Deploy the stack
cd /mnt/fast/apps/homelab/admin
docker compose up -d arcane
```

## Troubleshooting

### Arcane Fails to Start After Restore

Check logs for SQLite errors:

```bash
docker logs arcane --tail 50

# Common causes:
# - Stale .db-shm / .db-wal files from a previous crashed session
# - File permissions (must be readable/writable by PUID=3000)
# - Corrupted database file
```

Fix stale WAL files:

```bash
cd /mnt/fast/apps/homelab/corsair/admin
docker compose stop arcane

# Force WAL checkpoint and remove files
sqlite3 /mnt/fast/apps/homelab/corsair/admin/arcane/arcane.db "PRAGMA wal_checkpoint(TRUNCATE);"
rm -f /mnt/fast/apps/homelab/corsair/admin/arcane/arcane.db-shm
rm -f /mnt/fast/apps/homelab/corsair/admin/arcane/arcane.db-wal

docker compose up -d arcane
```

### Stacks Appear Empty or Missing

Arcane reads stack definitions from the live filesystem (`/mnt/fast/apps/homelab`), which is mounted read-only. If stacks appear empty after restore:

1. **Verify the mount is healthy**:
   ```bash
   docker inspect arcane | grep -A5 Mounts
   ls /mnt/fast/apps/homelab
   ```

2. **Check the `PROJECTS_DIRECTORY` env var** in `compose.yml` points to the correct path.

3. The database only stores metadata — stack compose files always come from disk.

### Database Corruption

If `PRAGMA integrity_check` reports errors:

```bash
# Try the most recent clean backup
for f in $(ls -t /mnt/tank/backups/homelab/arcane/db-daily-*.sqlite3); do
  echo "Checking $f..."
  result=$(sqlite3 "$f" "PRAGMA integrity_check;" 2>&1)
  echo "$result"
  if [ "$result" = "ok" ]; then
    echo "  → Use this backup: $f"
    break
  fi
done
```

### Permission Errors

```bash
# Arcane runs as PUID=3000 / PGID=3002
sudo chown 3000:3002 /mnt/fast/apps/homelab/corsair/admin/arcane/arcane.db
sudo chmod 644 /mnt/fast/apps/homelab/corsair/admin/arcane/arcane.db
```

## Backup Validation

```bash
# Quick integrity check
sqlite3 /mnt/tank/backups/homelab/arcane/db-daily-20251104-1900.sqlite3 \
  "PRAGMA integrity_check;"

# Check file size (should be at least several KB for an active install)
ls -lh /mnt/tank/backups/homelab/arcane/

# List all available backups
ls -lht /mnt/tank/backups/homelab/arcane/
```

## Backup Types

| Type | Retention | When Created |
|------|-----------|--------------|
| twice-daily | 3 days | 7 AM, 7 PM |
| daily | 7 days | 7 PM |
| weekly | 28 days | Sunday 7 PM |
| monthly | 180 days | 1st of month, 7 PM |

## Important Notes

- **Live state is always from Docker**: Container status, resource usage, and image info are always pulled live — restoring the database does not affect running containers
- **Stack files live on disk**: Arcane does not own the compose files; they are part of the homelab git repo at `/mnt/fast/apps/homelab`
- **Consistent backup method**: The backup uses SQLite's online backup API (via Python) while the container is running, ensuring a consistent snapshot without downtime; falls back to a direct `docker cp` if Python is unavailable
- **WAL/SHM files**: These are transient files; do not restore them — always remove them before starting Arcane with a restored database