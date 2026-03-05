# Seerr Restore Guide

Restore Seerr (media request management) configuration and request database.

## What's Backed Up

- **settings.json** - All configuration (Plex/Jellyfin connection, auth, notifications, permissions)
- **db/** - Request database (all media requests, users, issues, discovery settings)
- **anime-list.xml** - Custom anime mapping list

**Excluded from backup:**
- `logs/` - Log files (not needed for restore)
- `cache/` - Cached API responses (regenerated automatically)

## Backup Location

```
/mnt/tank/backups/homelab/seerr/
├── full-twice-daily-20251113-0700.tar.gz
├── full-daily-20251112-1900.tar.gz
├── full-weekly-20251110-1900.tar.gz
└── full-monthly-20251101-1900.tar.gz
```

## Quick Restore

### 1. Stop Seerr

```bash
cd /mnt/fast/apps/homelab/corsair/7seas
docker compose stop seerr
```

### 2. Backup Current Data (Optional but Recommended)

```bash
sudo mv /mnt/fast/apps/homelab/corsair/7seas/seerr \
   /mnt/fast/apps/homelab/corsair/7seas/seerr.backup.$(date +%Y%m%d-%H%M)
```

### 3. Restore Full Backup

```bash
# Choose your backup file
BACKUP_FILE="/mnt/tank/backups/homelab/seerr/full-daily-20251104-1900.tar.gz"

# Create parent directory if needed
sudo mkdir -p /mnt/fast/apps/homelab/corsair/7seas/

# Extract backup
sudo tar -xzf "$BACKUP_FILE" -C /mnt/fast/apps/homelab/corsair/7seas/

# Fix permissions
sudo chown -R 3000:3002 /mnt/fast/apps/homelab/corsair/7seas/seerr
```

### 4. Start Seerr

```bash
cd /mnt/fast/apps/homelab/corsair/7seas
docker compose up -d seerr
```

### 5. Verify Restore

```bash
# Check logs
docker logs seerr -f

# Wait for startup and verify health
curl -s http://localhost:5055/api/v1/status | python3 -m json.tool

# Access web UI
# Navigate to https://seerr.corsair.tf

# Verify:
# - All previous requests are visible
# - Users and permissions are intact
# - Media server connection (Plex/Jellyfin) is working
# - Notification agents are configured
# - Radarr/Sonarr integrations are connected
```

## What to Expect After Restore

- ✅ All media requests restored (pending, approved, available)
- ✅ User accounts and permissions intact
- ✅ Media server connection settings restored
- ✅ Download client integrations (Radarr/Sonarr) restored
- ✅ Notification settings preserved
- ✅ Discovery and watchlist settings intact
- ⚠️ Cache will be rebuilt on first startup (normal)
- ⚠️ Log history not restored (excluded to save space)

## Verify Backup Before Restore

```bash
# List contents of backup
tar -tzf /mnt/tank/backups/homelab/seerr/full-daily-20251104-1900.tar.gz | head -20

# Should show:
# seerr/settings.json
# seerr/db/
# seerr/db/db.sqlite3  (or similar)
# seerr/anime-list.xml
```

## Partial Restore

### Settings Only

If you only need to restore the configuration (e.g., after a fresh install):

```bash
# Extract just settings.json
tar -xzf /mnt/tank/backups/homelab/seerr/full-daily-20251104-1900.tar.gz \
  -C /tmp/ seerr/settings.json

# Copy to target
sudo cp /tmp/seerr/settings.json /mnt/fast/apps/homelab/corsair/7seas/seerr/settings.json

# Fix permissions
sudo chown 3000:3002 /mnt/fast/apps/homelab/corsair/7seas/seerr/settings.json

# Restart
docker compose restart seerr
```

### Database Only

If you only need to restore requests/users (keeping existing settings):

```bash
# Extract just the db directory
tar -xzf /mnt/tank/backups/homelab/seerr/full-daily-20251104-1900.tar.gz \
  -C /tmp/ seerr/db/

# Stop container
cd /mnt/fast/apps/homelab/corsair/7seas
docker compose stop seerr

# Replace db directory
sudo rm -rf /mnt/fast/apps/homelab/corsair/7seas/seerr/db
sudo cp -r /tmp/seerr/db /mnt/fast/apps/homelab/corsair/7seas/seerr/db
sudo chown -R 3000:3002 /mnt/fast/apps/homelab/corsair/7seas/seerr/db

# Start container
docker compose up -d seerr
```

## Restore to New System

```bash
# 1. Create directory structure
sudo mkdir -p /mnt/fast/apps/homelab/corsair/7seas/

# 2. Choose backup file
BACKUP_FILE="/mnt/tank/backups/homelab/seerr/full-daily-20251104-1900.tar.gz"

# 3. Extract backup
sudo tar -xzf "$BACKUP_FILE" -C /mnt/fast/apps/homelab/corsair/7seas/

# 4. Fix ownership
sudo chown -R 3000:3002 /mnt/fast/apps/homelab/corsair/7seas/seerr

# 5. Start Seerr
cd /mnt/fast/apps/homelab/corsair/7seas
docker compose up -d seerr
```

## Troubleshooting

### Media Server Connection Failed After Restore

If Seerr can't connect to Plex/Jellyfin:

1. **Verify media server is running**:
   ```bash
   docker ps | grep jellyfin
   ```

2. **Check settings.json** has the correct server URL and API key:
   ```bash
   cat /mnt/fast/apps/homelab/corsair/7seas/seerr/settings.json | python3 -m json.tool | grep -A5 "mediaServer"
   ```

3. **Re-enter credentials** via web UI: Settings → Plex/Jellyfin

### Radarr/Sonarr Integration Broken

If the *arr integrations show as unreachable:

1. **Check *arr services are running**:
   ```bash
   docker ps | grep -E "radarr|sonarr"
   ```

2. **Verify API keys** in Settings → Services (they may have changed if *arr was also restored)

3. **Test connection** via the web UI settings page for each integration

### Permission Errors on Startup

```bash
# Fix ownership recursively
sudo chown -R 3000:3002 /mnt/fast/apps/homelab/corsair/7seas/seerr
sudo chmod -R 755 /mnt/fast/apps/homelab/corsair/7seas/seerr
sudo chmod 644 /mnt/fast/apps/homelab/corsair/7seas/seerr/settings.json
```

### Requests Missing After Restore

If requests are missing, verify the correct backup was used:

```bash
# Check the db directory contents
tar -tzf /mnt/tank/backups/homelab/seerr/full-daily-20251104-1900.tar.gz | grep db/

# Check db file size (should not be near-empty)
tar -tvzf /mnt/tank/backups/homelab/seerr/full-daily-20251104-1900.tar.gz | grep db/
```

### Container Keeps Restarting

Check logs for configuration errors:

```bash
docker logs seerr --tail 50

# Common causes:
# - Invalid settings.json (syntax error)
# - Corrupted database file
# - Missing required config fields
```

If `settings.json` is corrupted:

```bash
# Validate JSON syntax
cat /mnt/fast/apps/homelab/corsair/7seas/seerr/settings.json | python3 -m json.tool
```

## Migration to New Server

To move Seerr to a new server:

1. **On old server**: Backup is already automated
2. **On new server**:
   - Deploy the compose stack from `/mnt/fast/apps/homelab/corsair/7seas/compose.yml`
   - Stop the container before it initializes
   - Restore backup as described above
   - Update DNS to point to new server
   - Start container

## Backup Validation

Verify your backup is complete and healthy:

```bash
# List contents of backup
tar -tzf /mnt/tank/backups/homelab/seerr/full-daily-20251104-1900.tar.gz

# Should include:
# seerr/settings.json
# seerr/db/
# seerr/anime-list.xml

# Check backup size (should be at least a few MB with active data)
ls -lh /mnt/tank/backups/homelab/seerr/full-daily-20251104-1900.tar.gz
```

## Backup Types

| Type | Retention | When Created |
|------|-----------|--------------|
| twice-daily | 3 days | 7 AM, 7 PM |
| daily | 7 days | 7 PM |
| weekly | 28 days | Sunday 7 PM |
| monthly | 180 days | 1st of month, 7 PM |

## Important Notes

- **API keys in settings.json**: The settings file contains Radarr/Sonarr/Jellyfin API keys — keep backups secure
- **Safe while running**: Backups are taken while Seerr is running (the SQLite WAL mode handles concurrent access safely)
- **Cache excluded**: The `cache/` directory is omitted — it rebuilds automatically and can be very large
- **All-in-one**: Single tar.gz contains everything needed for a full restore