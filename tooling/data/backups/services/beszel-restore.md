# Beszel Restore Guide

Restore Beszel (server monitoring dashboard) PocketBase database and configuration.

## What's Backed Up

- **beszel_data/** - PocketBase database directory containing:
  - `data.db` - Main PocketBase SQLite database (users, systems, chart data, alert rules, settings)
  - `data.db-shm` / `data.db-wal` - SQLite WAL mode files (if present)

**Excluded from backup:**
- `logs/` - Log files (not needed for restore)

**Not backed up (not needed):**
- `beszel_agent_data/` - Agent runtime state; the agent reconnects automatically
- `beszel_socket/` - Unix socket; recreated at container start

## Backup Location

```
/mnt/tank/backups/homelab/beszel/
├── full-twice-daily-20251113-0700.tar.gz
├── full-daily-20251112-1900.tar.gz
├── full-weekly-20251110-1900.tar.gz
└── full-monthly-20251101-1900.tar.gz
```

## Quick Restore

### 1. Stop Beszel

```bash
cd /mnt/fast/apps/homelab/admin
docker compose stop beszel
```

### 2. Backup Current Data (Optional but Recommended)

```bash
sudo mv /mnt/fast/apps/homelab/corsair/admin/beszel/beszel_data \
   /mnt/fast/apps/homelab/corsair/admin/beszel/beszel_data.backup.$(date +%Y%m%d-%H%M)
```

### 3. Restore Full Backup

```bash
# Choose your backup file
BACKUP_FILE="/mnt/tank/backups/homelab/beszel/full-daily-20251104-1900.tar.gz"

# Create parent directory if needed
sudo mkdir -p /mnt/fast/apps/homelab/corsair/admin/beszel/

# Extract backup (restores beszel_data/ directory)
sudo tar -xzf "$BACKUP_FILE" -C /mnt/fast/apps/homelab/corsair/admin/beszel/

# Fix permissions
sudo chown -R max:homelab /mnt/fast/apps/homelab/corsair/admin/beszel/beszel_data
```

### 4. Start Beszel

```bash
cd /mnt/fast/apps/homelab/admin
docker compose up -d beszel
```

### 5. Verify Restore

```bash
# Check logs
docker logs beszel -f

# Access web UI
# Navigate to https://status.corsair.tf

# Verify:
# - All monitored systems are listed
# - Historical chart data is visible
# - Alert rules are configured
# - User accounts and credentials work
# - Agent connections re-establish (may take a few seconds)
```

## What to Expect After Restore

- ✅ All monitored systems (hosts) restored
- ✅ Historical metrics and chart data intact
- ✅ Alert rules and notification settings preserved
- ✅ User accounts and credentials restored
- ✅ Dashboard layout and preferences restored
- ⚠️ Agent connections will re-establish automatically within a few seconds
- ⚠️ Real-time metrics gap during the downtime period is expected

## Verify Backup Before Restore

```bash
# List contents of backup
tar -tzf /mnt/tank/backups/homelab/beszel/full-daily-20251104-1900.tar.gz | head -20

# Should show:
# beszel_data/
# beszel_data/data.db
# beszel_data/data.db-shm   (optional, WAL mode)
# beszel_data/data.db-wal   (optional, WAL mode)
```

## Restore to New System

```bash
# 1. Create directory structure
sudo mkdir -p /mnt/fast/apps/homelab/corsair/admin/beszel/{beszel_data,beszel_agent_data,beszel_socket}

# 2. Choose backup file
BACKUP_FILE="/mnt/tank/backups/homelab/beszel/full-daily-20251104-1900.tar.gz"

# 3. Extract backup
sudo tar -xzf "$BACKUP_FILE" -C /mnt/fast/apps/homelab/corsair/admin/beszel/

# 4. Fix ownership
sudo chown -R max:homelab /mnt/fast/apps/homelab/corsair/admin/beszel/beszel_data

# 5. Deploy the stack
cd /mnt/fast/apps/homelab/admin
docker compose up -d beszel beszel-agent
```

## Troubleshooting

### Web UI Not Loading After Restore

Check logs for PocketBase startup errors:

```bash
docker logs beszel --tail 50

# Common causes:
# - Corrupted data.db file
# - Permissions on beszel_data/ directory
# - Port conflict
```

### Database Corruption

If PocketBase reports a corrupted database:

```bash
# Stop container
cd /mnt/fast/apps/homelab/corsair/admin
docker compose stop beszel

# Verify SQLite integrity
sqlite3 /mnt/fast/apps/homelab/corsair/admin/beszel/beszel_data/data.db "PRAGMA integrity_check;"

# If corrupt, try an older backup
BACKUP_FILE="/mnt/tank/backups/homelab/beszel/full-weekly-20251110-1900.tar.gz"
sudo tar -xzf "$BACKUP_FILE" -C /mnt/fast/apps/homelab/corsair/admin/beszel/

docker compose up -d beszel
```

### Agent Not Reconnecting

If the beszel-agent doesn't reconnect after restore:

```bash
# Restart the agent
cd /mnt/fast/apps/homelab/admin
docker compose restart beszel-agent

# Check agent logs
docker logs beszel-agent --tail 30
```

The agent authenticates via the socket file — ensure `beszel_socket/` exists and is writable:

```bash
ls -la /mnt/fast/apps/homelab/corsair/admin/beszel/beszel_socket/
```

### Permission Errors

```bash
# Fix ownership
sudo chown -R max:homelab /mnt/fast/apps/homelab/corsair/admin/beszel/beszel_data

# Fix permissions
sudo chmod -R 755 /mnt/fast/apps/homelab/corsair/admin/beszel/beszel_data
sudo chmod 644 /mnt/fast/apps/homelab/corsair/admin/beszel/beszel_data/data.db
```

### Can't Log In After Restore

If you can log in but the session is rejected, clear your browser cookies for `status.corsair.tf` and try again — sessions are not persisted in the backup.

If you've lost your admin credentials entirely:

```bash
# PocketBase admin reset - start container and use the superuser endpoint
# See: https://pocketbase.io/docs/going-to-production/#backup-and-restore
docker logs beszel 2>&1 | grep "superuser"
```

## Migration to New Server

To move Beszel to a new server:

1. **On old server**: Backup is already automated
2. **On new server**:
   - Clone the compose stack from `/mnt/fast/apps/homelab/corsair/admin/compose.yml`
   - Create the directory skeleton:
     ```bash
     mkdir -p /mnt/fast/apps/homelab/corsair/admin/beszel/{beszel_data,beszel_agent_data,beszel_socket}
     ```
   - Restore backup as described above
   - Update DNS to point `status.corsair.tf` to the new server IP
   - Start the stack:
     ```bash
     docker compose up -d beszel beszel-agent
     ```
   - Update any remote agents to connect to the new server address

## Backup Validation

```bash
# List contents of backup
tar -tzf /mnt/tank/backups/homelab/beszel/full-daily-20251104-1900.tar.gz

# Should include:
# beszel_data/data.db

# Verify SQLite integrity without extracting
mkdir -p /tmp/beszel-check
tar -xzf /mnt/tank/backups/homelab/beszel/full-daily-20251104-1900.tar.gz \
  -C /tmp/beszel-check beszel_data/data.db
sqlite3 /tmp/beszel-check/beszel_data/data.db "PRAGMA integrity_check;"
rm -rf /tmp/beszel-check
```

## Backup Types

| Type | Retention | When Created |
|------|-----------|--------------|
| twice-daily | 3 days | 7 AM, 7 PM |
| daily | 7 days | 7 PM |
| weekly | 28 days | Sunday 7 PM |
| monthly | 180 days | 1st of month, 7 PM |

## Important Notes

- **Metrics gap is normal**: Any metrics collected during the downtime window will be missing — this is expected
- **Agent auto-reconnects**: The `beszel-agent` container does not need restoring; it reconnects to the hub automatically
- **PocketBase WAL mode**: The `data.db-shm` and `data.db-wal` files are backed up alongside `data.db` for a consistent snapshot
- **Safe while running**: The backup is taken while Beszel is running; PocketBase's WAL mode ensures data consistency
- **Browser sessions**: Active web sessions are not persisted — users will need to log in again after a restore