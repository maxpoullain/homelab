# OctoPrint Restore Guide

Restore OctoPrint (3D printer management) configuration, plugins, and uploaded files.

## What's Backed Up

- **config.yaml** - Main OctoPrint configuration (server settings, webcam, serial, access control)
- **users.yaml** - User accounts and API keys
- **plugins/** - Plugin data and configurations
- **uploads/** - Uploaded G-code files and STL models
- **data/** - Additional OctoPrint application data

**Excluded from backup:**
- `logs/` - Log files (not needed for restore)
- `.cache/` - Temporary cache data (regenerated automatically)
- `timelapse/` - Timelapse recordings (large, regenerable)

**Note on permissions**: OctoPrint runs as `root` inside its container. On the host, the data files are owned by `root:homelab` with mode `600`/`640`, making them unreadable by the backup user. The backup therefore uses `docker cp` to pull the data directory out of the running container (which has root access), then tars the result.

## Backup Location

```
/mnt/tank/backups/homelab/octoprint/
├── full-twice-daily-20251113-0700.tar.gz
├── full-daily-20251112-1900.tar.gz
├── full-weekly-20251110-1900.tar.gz
└── full-monthly-20251101-1900.tar.gz
```

## Quick Restore

### 1. Stop OctoPrint

```bash
cd /mnt/fast/apps/homelab/misc
docker compose stop octoprint
```

### 2. Backup Current Data (Optional but Recommended)

```bash
sudo mv /mnt/fast/apps/homelab/corsair/misc/octoprint/octoprint \
   /mnt/fast/apps/homelab/corsair/misc/octoprint/octoprint.backup.$(date +%Y%m%d-%H%M)
```

### 3. Restore Full Backup

```bash
# Choose your backup file
BACKUP_FILE="/mnt/tank/backups/homelab/octoprint/full-daily-20251104-1900.tar.gz"

# Create the octoprint data directory if needed
sudo mkdir -p /mnt/fast/apps/homelab/corsair/misc/octoprint/octoprint

# Extract backup into the octoprint data directory
# (the archive root is the contents of octoprint/, not octoprint/ itself)
sudo tar -xzf "$BACKUP_FILE" -C /mnt/fast/apps/homelab/corsair/misc/octoprint/octoprint/

# Fix permissions (container runs as root, files should be root:homelab)
sudo chown -R root:homelab /mnt/fast/apps/homelab/corsair/misc/octoprint/octoprint
sudo chmod -R 755 /mnt/fast/apps/homelab/corsair/misc/octoprint/octoprint
sudo chmod 640 /mnt/fast/apps/homelab/corsair/misc/octoprint/octoprint/config.yaml
sudo chmod 640 /mnt/fast/apps/homelab/corsair/misc/octoprint/octoprint/users.yaml 2>/dev/null || true
```

### 4. Start OctoPrint

```bash
cd /mnt/fast/apps/homelab/misc
docker compose up -d octoprint
```

### 5. Verify Restore

```bash
# Check logs
docker logs octoprint -f

# Access web UI
# Navigate to https://octoprint.corsair.tf

# Verify:
# - User login works
# - Printer profile is configured correctly
# - Plugins are installed and active
# - Uploaded G-code files are present
# - Serial connection to printer can be established
```

## What to Expect After Restore

- ✅ All configuration settings restored (serial port, baudrate, webcam, etc.)
- ✅ User accounts and API keys intact
- ✅ Installed plugin configurations preserved
- ✅ Uploaded G-code files and models restored
- ✅ Printer profiles and bed dimensions restored
- ⚠️ Timelapse recordings not restored (excluded to save space)
- ⚠️ Plugin binaries may need reinstalling if the image was rebuilt (config is preserved)
- ⚠️ Print history database (if stored in logs) not restored

## Verify Backup Before Restore

```bash
# List contents of backup
tar -tzf /mnt/tank/backups/homelab/octoprint/full-daily-20251104-1900.tar.gz | head -30

# Should show:
# octoprint/
# octoprint/config.yaml
# octoprint/users.yaml
# octoprint/plugins/
# octoprint/uploads/

# Check backup size
ls -lh /mnt/tank/backups/homelab/octoprint/full-daily-20251104-1900.tar.gz
```

## Partial Restore

### Configuration Only

If you only need to restore settings (e.g., after a fresh install, keeping existing uploads):

```bash
# Extract just config.yaml and users.yaml to a temp dir
mkdir -p /tmp/octoprint-restore
tar -xzf /mnt/tank/backups/homelab/octoprint/full-daily-20251104-1900.tar.gz \
  -C /tmp/octoprint-restore/ ./config.yaml ./users.yaml 2>/dev/null || \
tar -xzf /mnt/tank/backups/homelab/octoprint/full-daily-20251104-1900.tar.gz \
  -C /tmp/octoprint-restore/

cd /mnt/fast/apps/homelab/misc
docker compose stop octoprint

sudo cp /tmp/octoprint-restore/config.yaml \
   /mnt/fast/apps/homelab/corsair/misc/octoprint/octoprint/config.yaml
sudo cp /tmp/octoprint-restore/users.yaml \
   /mnt/fast/apps/homelab/corsair/misc/octoprint/octoprint/users.yaml

sudo chown root:homelab \
   /mnt/fast/apps/homelab/corsair/misc/octoprint/octoprint/config.yaml \
   /mnt/fast/apps/homelab/corsair/misc/octoprint/octoprint/users.yaml
sudo chmod 640 \
   /mnt/fast/apps/homelab/corsair/misc/octoprint/octoprint/config.yaml \
   /mnt/fast/apps/homelab/corsair/misc/octoprint/octoprint/users.yaml

rm -rf /tmp/octoprint-restore
docker compose up -d octoprint
```

### Uploads Only

If you only need to restore G-code files (keeping existing configuration):

```bash
mkdir -p /tmp/octoprint-restore
tar -xzf /mnt/tank/backups/homelab/octoprint/full-daily-20251104-1900.tar.gz \
  -C /tmp/octoprint-restore/

cd /mnt/fast/apps/homelab/corsair/misc
docker compose stop octoprint

sudo rm -rf /mnt/fast/apps/homelab/corsair/misc/octoprint/octoprint/uploads
sudo cp -r /tmp/octoprint-restore/uploads \
   /mnt/fast/apps/homelab/corsair/misc/octoprint/octoprint/uploads
sudo chown -R root:homelab \
   /mnt/fast/apps/homelab/corsair/misc/octoprint/octoprint/uploads

rm -rf /tmp/octoprint-restore
docker compose up -d octoprint
```

### Plugins Only

If you only need to restore plugin configurations:

```bash
mkdir -p /tmp/octoprint-restore
tar -xzf /mnt/tank/backups/homelab/octoprint/full-daily-20251104-1900.tar.gz \
  -C /tmp/octoprint-restore/

cd /mnt/fast/apps/homelab/corsair/misc
docker compose stop octoprint

sudo rm -rf /mnt/fast/apps/homelab/corsair/misc/octoprint/octoprint/plugins
sudo cp -r /tmp/octoprint-restore/plugins \
   /mnt/fast/apps/homelab/corsair/misc/octoprint/octoprint/plugins
sudo chown -R root:homelab \
   /mnt/fast/apps/homelab/corsair/misc/octoprint/octoprint/plugins

rm -rf /tmp/octoprint-restore
docker compose up -d octoprint
```

## Restore to New System

```bash
# 1. Create directory structure
sudo mkdir -p /mnt/fast/apps/homelab/corsair/misc/octoprint/octoprint

# 2. Choose backup file
BACKUP_FILE="/mnt/tank/backups/homelab/octoprint/full-daily-20251104-1900.tar.gz"

# 3. Extract backup into the data directory
sudo tar -xzf "$BACKUP_FILE" -C /mnt/fast/apps/homelab/corsair/misc/octoprint/octoprint/

# 4. Fix ownership (container runs as root)
sudo chown -R root:homelab /mnt/fast/apps/homelab/corsair/misc/octoprint/octoprint
sudo chmod -R 755 /mnt/fast/apps/homelab/corsair/misc/octoprint/octoprint
sudo chmod 640 /mnt/fast/apps/homelab/corsair/misc/octoprint/octoprint/config.yaml
sudo chmod 640 /mnt/fast/apps/homelab/corsair/misc/octoprint/octoprint/users.yaml 2>/dev/null || true

# 5. Verify USB serial device path in compose.yml matches new system
cat /mnt/fast/apps/homelab/corsair/misc/compose.yml | grep devices -A5
ls /dev/serial/by-id/

# 6. Update device path in compose.yml if needed, then deploy
cd /mnt/fast/apps/homelab/misc
docker compose up -d octoprint
```

## Troubleshooting

### Printer Not Connecting After Restore

The USB serial device path may have changed or the printer may not be detected:

1. **Check USB device is present**:
   ```bash
   ls -l /dev/serial/by-id/
   # Should show your printer's USB serial adapter
   ```

2. **Verify device path in compose.yml**:
   ```bash
   cat /mnt/fast/apps/homelab/corsair/misc/compose.yml | grep -A2 devices
   # Should match the actual /dev/serial/by-id/... path
   ```

3. **Check serial settings in OctoPrint UI**:
   - Settings → Serial Connection → Baudrate & Port
   - Try AUTO detection if the device path has changed

4. **Check container has access to the device**:
   ```bash
   docker exec octoprint ls -l /dev/ttyUSB0
   ```

### Plugins Not Working After Restore

Plugin binaries are not backed up — only their configuration data. If plugins are missing after restoring to a new container image:

1. **Access OctoPrint web UI** → Plugin Manager
2. **Reinstall missing plugins** — their configurations from the backup will be applied automatically
3. **Restart OctoPrint** after reinstalling:
   ```bash
   docker compose restart octoprint
   ```

### Permission Denied Errors

OctoPrint runs as `root` inside the container. On the host the files are owned by `root:homelab`:

```bash
# Fix all permissions recursively
sudo chown -R root:homelab /mnt/fast/apps/homelab/corsair/misc/octoprint/octoprint
sudo chmod -R 755 /mnt/fast/apps/homelab/corsair/misc/octoprint/octoprint
sudo chmod 640 /mnt/fast/apps/homelab/corsair/misc/octoprint/octoprint/config.yaml
sudo chmod 640 /mnt/fast/apps/homelab/corsair/misc/octoprint/octoprint/users.yaml 2>/dev/null || true
```

### Container Keeps Restarting

Check logs for startup errors:

```bash
docker logs octoprint --tail 50

# Common causes:
# - config.yaml syntax error
# - Missing or inaccessible serial device
# - Permission issues on data directory
```

Validate config.yaml syntax:

```bash
# YAML syntax check
python3 -c "
import yaml
with open('/mnt/fast/apps/homelab/corsair/misc/octoprint/octoprint/config.yaml') as f:
    yaml.safe_load(f)
print('config.yaml is valid')
"
```

### Web UI Not Accessible

1. **Check container is running**:
   ```bash
   docker ps | grep octoprint
   ```

2. **Check Traefik is routing correctly**:
   ```bash
   docker logs traefik 2>&1 | grep octoprint
   ```

3. **Verify the container port** — OctoPrint serves on port 80 inside the container (mapped via Traefik).

### Forgotten Admin Password

If you've lost the admin password and the backup's `users.yaml` also has an unknown password:

```bash
# Stop container
cd /mnt/fast/apps/homelab/misc
docker compose stop octoprint

# Remove users.yaml to trigger first-run setup wizard
sudo mv /mnt/fast/apps/homelab/corsair/misc/octoprint/octoprint/users.yaml \
   /mnt/fast/apps/homelab/corsair/misc/octoprint/octoprint/users.yaml.bak

# Also disable access control temporarily in config.yaml
sudo sed -i 's/enabled: true/enabled: false/' \
   /mnt/fast/apps/homelab/corsair/misc/octoprint/octoprint/config.yaml

# Start and set up new credentials via UI, then re-enable access control
docker compose up -d octoprint
```

## Migration to New Server

To move OctoPrint to a new server:

1. **On old server**: Backup is already automated
2. **On new server**:
   - Check that a compatible USB serial adapter is available
   - Note the device path: `ls /dev/serial/by-id/`
   - Deploy the compose stack from `/mnt/fast/apps/homelab/corsair/misc/compose.yml`
   - Update the `devices:` section in `compose.yml` to match the new device path if needed
   - Restore backup as described in **Restore to New System** above
   - Update DNS to point `octoprint.corsair.tf` to the new server
   - Start the container

**Important**: The 3D printer's USB cable must be plugged into the new server.

## Backup Validation

```bash
# List all available OctoPrint backups
ls -lht /mnt/tank/backups/homelab/octoprint/

# Verify a specific backup is readable and non-empty
tar -tzf /mnt/tank/backups/homelab/octoprint/full-daily-20251104-1900.tar.gz | head -30

# Verify backup contains critical files
# Note: archive root is the contents of octoprint/, not a octoprint/ wrapper directory
tar -tzf /mnt/tank/backups/homelab/octoprint/full-daily-20251104-1900.tar.gz | \
  grep -E "(config\.yaml|users\.yaml)" && echo "Critical files present"

# Check backup size (a healthy backup with plugins/uploads should be several MB)
ls -lh /mnt/tank/backups/homelab/octoprint/full-daily-20251104-1900.tar.gz
```

## Backup Types

| Type | Retention | When Created |
|------|-----------|--------------|
| twice-daily | 3 days | 7 AM, 7 PM |
| daily | 7 days | 7 PM |
| weekly | 28 days | Sunday 7 PM |
| monthly | 180 days | 1st of month, 7 PM |

## Important Notes

- **USB device path**: The serial device path (`/dev/serial/by-id/...`) is set in `compose.yml` — update it if migrating to a new server or if the USB adapter changes
- **Timelapse excluded**: The `timelapse/` directory can grow very large and is excluded from backups — save important timelapses manually before they are lost
- **Plugin binaries not backed up**: Plugin configuration is backed up, but plugin binaries live inside the Docker image; they will reinstall automatically from OctoPrint's plugin manager on first run
- **Backup uses `docker cp`**: Because OctoPrint data files are owned by `root:root 600` on the host (unreadable by the backup user), the backup pulls files out via `docker cp` from the running container instead of reading them directly from disk
- **Archive structure**: The tar archive contains the *contents* of the `octoprint/` data directory at its root (not a wrapping `octoprint/` subdirectory) — extract with `-C .../octoprint/octoprint/`
- **Safe while running**: Avoid running the backup during an active print job if possible, as `config.yaml` may be mid-write; for routine scheduled backups this risk is negligible
- **Printer profile**: After restoring, verify the printer profile in Settings → Printer Profiles matches your actual printer dimensions and settings