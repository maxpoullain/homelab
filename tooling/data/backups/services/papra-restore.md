# Papra Restore Guide

Restore Papra (document archive) database and document files.

## What's Backed Up

- **db-[type]-[date].sqlite3** - Papra SQLite database (organizations, documents metadata, users, tags, settings)
- **db-[type]-[date].sqlite3-wal** - SQLite WAL file (if Papra was active during backup — required for a consistent restore)
- **db-[type]-[date].sqlite3-shm** - SQLite SHM file (companion to WAL — required if WAL is present)
- **documents-[type]-[date].tar.gz** - Uploaded document files (PDFs and other files stored on disk)

**All files from the same backup run are required for a complete restore.**
The WAL and SHM files must be restored alongside the main `.sqlite3` file if they are present in the backup.

**Not backed up:**
- Temporary files and internal caches (regenerated automatically)

## Backup Location

```
/mnt/tank/backups/homelab/papra/
├── db-twice-daily-20251113-0700.sqlite3
├── db-twice-daily-20251113-0700.sqlite3-wal   (present if Papra was active)
├── db-twice-daily-20251113-0700.sqlite3-shm   (present if WAL exists)
├── documents-twice-daily-20251113-0700.tar.gz
├── db-daily-20251112-1900.sqlite3
├── documents-daily-20251112-1900.tar.gz
├── db-weekly-20251110-1900.sqlite3
├── documents-weekly-20251110-1900.tar.gz
└── ...
```

## Quick Restore

### 1. Stop Papra

```bash
cd /mnt/fast/apps/homelab/docs
docker compose stop papra
```

### 2. Backup Current Data (Optional but Recommended)

```bash
# Backup current database
cp /mnt/fast/apps/homelab/corsair/docs/papra/db/papra.db \
   /mnt/fast/apps/homelab/corsair/docs/papra/db/papra.db.backup.$(date +%Y%m%d-%H%M)

# Backup current documents
sudo mv /mnt/fast/apps/homelab/corsair/docs/papra/documents \
   /mnt/fast/apps/homelab/corsair/docs/papra/documents.backup.$(date +%Y%m%d-%H%M)
```

### 3. Restore Database

```bash
# Choose your backup timestamp (e.g., daily-20251104-1900)
BACKUP_DATE="daily-20251104-1900"
BACKUP_DIR="/mnt/tank/backups/homelab/papra"

# Restore main database file
cp "$BACKUP_DIR/db-$BACKUP_DATE.sqlite3" \
   /mnt/fast/apps/homelab/corsair/docs/papra/db/db.sqlite

# Restore WAL and SHM files if they exist in the backup
# (required for a consistent restore if Papra was running during backup)
[ -f "$BACKUP_DIR/db-$BACKUP_DATE.sqlite3-wal" ] && \
  cp "$BACKUP_DIR/db-$BACKUP_DATE.sqlite3-wal" \
     /mnt/fast/apps/homelab/corsair/docs/papra/db/db.sqlite-wal
[ -f "$BACKUP_DIR/db-$BACKUP_DATE.sqlite3-shm" ] && \
  cp "$BACKUP_DIR/db-$BACKUP_DATE.sqlite3-shm" \
     /mnt/fast/apps/homelab/corsair/docs/papra/db/db.sqlite-shm

# Fix permissions (Papra runs as user 3000:3000)
sudo chown 3000:3000 /mnt/fast/apps/homelab/corsair/docs/papra/db/db.sqlite
sudo chown 3000:3000 /mnt/fast/apps/homelab/corsair/docs/papra/db/db.sqlite-wal 2>/dev/null || true
sudo chown 3000:3000 /mnt/fast/apps/homelab/corsair/docs/papra/db/db.sqlite-shm 2>/dev/null || true
```

### 4. Restore Documents

```bash
# Restore documents directory
sudo tar -xzf "$BACKUP_DIR/documents-$BACKUP_DATE.tar.gz" \
  -C /mnt/fast/apps/homelab/corsair/docs/papra/

# Fix permissions
sudo chown -R 3000:3000 /mnt/fast/apps/homelab/corsair/docs/papra/documents
```

### 5. Start Papra

```bash
cd /mnt/fast/apps/homelab/docs
docker compose up -d papra
```

### 6. Verify Restore

```bash
# Check logs
docker logs papra -f

# Access web UI
# Navigate to https://archive.corsair.tf

# Verify:
# - All organizations are present
# - Documents are listed and accessible
# - Tags and metadata are intact
# - User accounts work correctly
# - Documents can be opened/downloaded
```

## What to Expect After Restore

- ✅ All organizations and their documents restored
- ✅ Document metadata (tags, dates, notes) intact
- ✅ User accounts and permissions restored
- ✅ Document files accessible and downloadable
- ✅ Search index will rebuild on startup

## Verify Backup Before Restore

```bash
BACKUP_DATE="daily-20251104-1900"
BACKUP_DIR="/mnt/tank/backups/homelab/papra"

# Check both files exist
ls -lh "$BACKUP_DIR/db-$BACKUP_DATE.sqlite3"
ls -lh "$BACKUP_DIR/documents-$BACKUP_DATE.tar.gz"

# Verify SQLite database integrity
# Copy to a temp dir first so sqlite3 can find the matching WAL/SHM files
tmpdir=$(mktemp -d)
cp "$BACKUP_DIR/db-$BACKUP_DATE.sqlite3" "$tmpdir/db.sqlite"
[ -f "$BACKUP_DIR/db-$BACKUP_DATE.sqlite3-wal" ] && \
  cp "$BACKUP_DIR/db-$BACKUP_DATE.sqlite3-wal" "$tmpdir/db.sqlite-wal"
[ -f "$BACKUP_DIR/db-$BACKUP_DATE.sqlite3-shm" ] && \
  cp "$BACKUP_DIR/db-$BACKUP_DATE.sqlite3-shm" "$tmpdir/db.sqlite-shm"
sqlite3 "$tmpdir/db.sqlite" "PRAGMA integrity_check;"
rm -rf "$tmpdir"
# Should output: ok

# List document archive contents
tar -tzf "$BACKUP_DIR/documents-$BACKUP_DATE.tar.gz" | head -20
```

## Partial Restore

### Database Only

If you only need to restore document metadata (keeping existing files on disk):

```bash
BACKUP_DIR="/mnt/tank/backups/homelab/papra"
BACKUP_DATE="daily-20251104-1900"

cd /mnt/fast/apps/homelab/docs
docker compose stop papra

cp "$BACKUP_DIR/db-$BACKUP_DATE.sqlite3" \
   /mnt/fast/apps/homelab/corsair/docs/papra/db/db.sqlite

[ -f "$BACKUP_DIR/db-$BACKUP_DATE.sqlite3-wal" ] && \
  cp "$BACKUP_DIR/db-$BACKUP_DATE.sqlite3-wal" \
     /mnt/fast/apps/homelab/corsair/docs/papra/db/db.sqlite-wal
[ -f "$BACKUP_DIR/db-$BACKUP_DATE.sqlite3-shm" ] && \
  cp "$BACKUP_DIR/db-$BACKUP_DATE.sqlite3-shm" \
     /mnt/fast/apps/homelab/corsair/docs/papra/db/db.sqlite-shm

sudo chown 3000:3000 /mnt/fast/apps/homelab/corsair/docs/papra/db/db.sqlite
sudo chown 3000:3000 /mnt/fast/apps/homelab/corsair/docs/papra/db/db.sqlite-wal 2>/dev/null || true
sudo chown 3000:3000 /mnt/fast/apps/homelab/corsair/docs/papra/db/db.sqlite-shm 2>/dev/null || true

docker compose up -d papra
```

### Documents Only

If you only need to restore document files (keeping existing database):

```bash
BACKUP_DIR="/mnt/tank/backups/homelab/papra"
BACKUP_DATE="daily-20251104-1900"

cd /mnt/fast/apps/homelab/corsair/docs
docker compose stop papra

sudo rm -rf /mnt/fast/apps/homelab/corsair/docs/papra/documents
sudo tar -xzf "$BACKUP_DIR/documents-$BACKUP_DATE.tar.gz" \
  -C /mnt/fast/apps/homelab/corsair/docs/papra/
sudo chown -R 3000:3000 /mnt/fast/apps/homelab/corsair/docs/papra/documents

docker compose up -d papra
```

## Restore to New System

```bash
# 1. Create directory structure
sudo mkdir -p /mnt/fast/apps/homelab/corsair/docs/papra/{db,documents}

# 2. Choose backup timestamp
BACKUP_DATE="daily-20251104-1900"
BACKUP_DIR="/mnt/tank/backups/homelab/papra"

# 3. Restore database
cp "$BACKUP_DIR/db-$BACKUP_DATE.sqlite3" \
   /mnt/fast/apps/homelab/corsair/docs/papra/db/db.sqlite

[ -f "$BACKUP_DIR/db-$BACKUP_DATE.sqlite3-wal" ] && \
  cp "$BACKUP_DIR/db-$BACKUP_DATE.sqlite3-wal" \
     /mnt/fast/apps/homelab/corsair/docs/papra/db/db.sqlite-wal
[ -f "$BACKUP_DIR/db-$BACKUP_DATE.sqlite3-shm" ] && \
  cp "$BACKUP_DIR/db-$BACKUP_DATE.sqlite3-shm" \
     /mnt/fast/apps/homelab/corsair/docs/papra/db/db.sqlite-shm

# 4. Restore documents
sudo tar -xzf "$BACKUP_DIR/documents-$BACKUP_DATE.tar.gz" \
  -C /mnt/fast/apps/homelab/corsair/docs/papra/

# 5. Fix permissions
sudo chown -R 3000:3000 /mnt/fast/apps/homelab/corsair/docs/papra/db
sudo chown -R 3000:3000 /mnt/fast/apps/homelab/corsair/docs/papra/documents

# 6. Deploy the stack
cd /mnt/fast/apps/homelab/docs
docker compose up -d papra
```

## Troubleshooting

### Documents Visible in UI But Can't Be Opened

This indicates a database/files mismatch — the DB references files that aren't present on disk (or vice versa). Ensure you restore both the database and the documents archive **from the same backup timestamp**:

```bash
# Confirm both files share the same timestamp
ls -lh /mnt/tank/backups/homelab/papra/ | grep "$BACKUP_DATE"
```

### Container Fails to Start

Check logs for errors:

```bash
docker logs papra --tail 50

# Common causes:
# - Stale .db-shm / .db-wal files
# - Permissions on db/ or documents/ directories
# - Missing papra.env file (check /mnt/fast/apps/homelab/corsair/docs/papra.env)
```

Fix stale WAL files (if you have `sqlite3` available on the host):

```bash
cd /mnt/fast/apps/homelab/docs
docker compose stop papra

sqlite3 /mnt/fast/apps/homelab/corsair/docs/papra/db/db.sqlite \
  "PRAGMA wal_checkpoint(TRUNCATE);"
rm -f /mnt/fast/apps/homelab/corsair/docs/papra/db/db.sqlite-shm
rm -f /mnt/fast/apps/homelab/corsair/docs/papra/db/db.sqlite-wal

docker compose up -d papra
```

If `sqlite3` is not available on the host, simply start the container — SQLite will automatically apply and checkpoint the WAL on first open:

```bash
docker compose up -d papra
```

### Permission Denied Errors

Papra runs as user `3000:3000`:

```bash
# Fix all permissions under the papra data directory
sudo chown -R 3000:3000 /mnt/fast/apps/homelab/corsair/docs/papra
sudo chmod -R 755 /mnt/fast/apps/homelab/corsair/docs/papra
sudo chmod 644 /mnt/fast/apps/homelab/corsair/docs/papra/db/db.sqlite
sudo chmod 644 /mnt/fast/apps/homelab/corsair/docs/papra/db/db.sqlite-wal 2>/dev/null || true
sudo chmod 644 /mnt/fast/apps/homelab/corsair/docs/papra/db/db.sqlite-shm 2>/dev/null || true
```

### Database Corruption

If integrity check fails, try progressively older backups:

```bash
for f in $(ls -t /mnt/tank/backups/homelab/papra/db-daily-*.sqlite3); do
  echo "Checking $f..."
  # Copy db + wal + shm to a temp location before checking, so sqlite3 can open consistently
  tmpdir=$(mktemp -d)
  cp "$f" "$tmpdir/db.sqlite"
  [ -f "${f}-wal" ] && cp "${f}-wal" "$tmpdir/db.sqlite-wal"
  [ -f "${f}-shm" ] && cp "${f}-shm" "$tmpdir/db.sqlite-shm"
  result=$(sqlite3 "$tmpdir/db.sqlite" "PRAGMA integrity_check;" 2>&1)
  rm -rf "$tmpdir"
  echo "$result"
  if [ "$result" = "ok" ]; then
    echo "  → Use this backup: $f"
    break
  fi
done
```

### Environment / Config Issues

Papra reads its configuration from `papra.env`:

```bash
# Verify env file exists and is readable
cat /mnt/fast/apps/homelab/corsair/docs/papra.env

# The encrypted version is at:
# /mnt/fast/apps/homelab/corsair/docs/encrypted.papra.env
```

## Migration to New Server

To move Papra to a new server:

1. **On old server**: Backup is already automated
2. **On new server**:
   - Set up the compose stack from `/mnt/fast/apps/homelab/corsair/docs/compose.yml`
   - Ensure `papra.env` is present (decrypt from `encrypted.papra.env` if needed)
   - Create the directory skeleton:
     ```bash
     sudo mkdir -p /mnt/fast/apps/homelab/corsair/docs/papra/{db,documents}
     ```
   - Restore backup as described in **Restore to New System** above
   - Update DNS to point `archive.corsair.tf` to the new server
   - Start the container

## Backup Validation

```bash
BACKUP_DATE="daily-20251104-1900"
BACKUP_DIR="/mnt/tank/backups/homelab/papra"

# Verify both backup files exist
ls -lh "$BACKUP_DIR/db-$BACKUP_DATE.sqlite3"
ls -lh "$BACKUP_DIR/documents-$BACKUP_DATE.tar.gz"

# Verify database integrity
sqlite3 "$BACKUP_DIR/db-$BACKUP_DATE.sqlite3" "PRAGMA integrity_check;"

# Count documents in archive
tar -tzf "$BACKUP_DIR/documents-$BACKUP_DATE.tar.gz" | wc -l
```

## Backup Types

| Type | Retention | When Created |
|------|-----------|--------------|
| twice-daily | 3 days | 7 AM, 7 PM |
| daily | 7 days | 7 PM |
| weekly | 28 days | Sunday 7 PM |
| monthly | 180 days | 1st of month, 7 PM |

## Important Notes

- **Keep db + documents in sync**: Always restore the database (`.sqlite3` + `.sqlite3-wal` + `.sqlite3-shm`) and the documents archive from the **same backup run** — the database records reference file paths that must exist on disk
- **WAL/SHM files are part of the backup set**: The backup copies `db.sqlite`, `db.sqlite-wal`, and `db.sqlite-shm` directly out of the running container with `docker cp`. SQLite guarantees that these three files together represent a consistent snapshot, so no shutdown is needed
- **Actual db filename is `db.sqlite`**: Papra stores its database at `/app/app-data/db/db.sqlite` inside the container. Backup files are named `db-[type]-[date].sqlite3` for consistency with other services
- **User credentials**: Authentication settings are stored in the database and restored automatically
- **Encryption keys**: If Papra uses any encryption for stored documents, ensure `papra.env` contains the correct keys before starting the restored container