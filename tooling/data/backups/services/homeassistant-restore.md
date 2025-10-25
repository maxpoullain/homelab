# Home Assistant Restore Guide

This guide explains how to restore Home Assistant from backups located in `/mnt/tank/backups/homelab/homeassistant/`.

## Backup Files

- `db-[type]-[date].sqlite3` - Main database (history, states, events)
- `zigbee-[type]-[date].sqlite3` - Zigbee database (device pairings, network config)
- `config-[type]-[date].tar.gz` - YAML configs (automations, scripts, configuration)

## Quick Restore

### 1. Stop Home Assistant

```bash
cd /mnt/fast/apps/homelab/home
docker compose down
```

### 2. Restore Databases

```bash
# Choose your backup timestamp
BACKUP_DATE="daily-20251025-2236"
BACKUP_DIR="/mnt/tank/backups/homelab/homeassistant"
HA_DIR="/mnt/fast/apps/homelab/home/ha"

# Restore main database
cp "$BACKUP_DIR/db-$BACKUP_DATE.sqlite3" "$HA_DIR/home-assistant_v2.db"

# Restore Zigbee database (if you have Zigbee devices)
if [ -f "$BACKUP_DIR/zigbee-$BACKUP_DATE.sqlite3" ]; then
  cp "$BACKUP_DIR/zigbee-$BACKUP_DATE.sqlite3" "$HA_DIR/zigbee.db"
fi

# Fix permissions
sudo chown -R root:root "$HA_DIR"/*.db
```

### 3. Restore Configuration Files

```bash
# Extract configs (this will overwrite existing files)
tar -xzf "$BACKUP_DIR/config-$BACKUP_DATE.tar.gz" -C /mnt/fast/apps/homelab/home/

# Fix permissions
sudo chown -R root:root /mnt/fast/apps/homelab/home/ha/
```

### 4. Start Home Assistant

```bash
cd /mnt/fast/apps/homelab/home
docker compose up -d
```

### 5. Verify Restore

```bash
# Check logs
docker logs ha

# Check HA is responsive
curl -k https://ha.yourdomain.com

# Verify Zigbee devices (if applicable)
# Go to Settings → Devices & Services → Zigbee Home Automation
```

## Partial Restore

### Database Only (Keep Current Configs)

If you only need to restore history/state data:

```bash
cd /mnt/fast/apps/homelab/home
docker compose down

cp /mnt/tank/backups/homelab/homeassistant/db-daily-20251025-2236.sqlite3 \
   /mnt/fast/apps/homelab/home/ha/home-assistant_v2.db

docker compose up -d
```

### Configs Only (Keep Current Database)

If you only need to restore automation/configuration files:

```bash
cd /mnt/fast/apps/homelab/home
docker compose down

tar -xzf /mnt/tank/backups/homelab/homeassistant/config-daily-20251025-2236.tar.gz \
  -C /mnt/fast/apps/homelab/home/

docker compose up -d
```

### Zigbee Database Only

If you need to restore Zigbee device pairings (e.g., after re-pairing issues):

```bash
cd /mnt/fast/apps/homelab/home
docker compose down

cp /mnt/tank/backups/homelab/homeassistant/zigbee-daily-20251025-2236.sqlite3 \
   /mnt/fast/apps/homelab/home/ha/zigbee.db

docker compose up -d
```

## Verify Backup Integrity

```bash
# Check main database
sqlite3 /mnt/tank/backups/homelab/homeassistant/db-daily-20251025-2236.sqlite3 \
  "PRAGMA integrity_check;"

# Check Zigbee database
sqlite3 /mnt/tank/backups/homelab/homeassistant/zigbee-daily-20251025-2236.sqlite3 \
  "PRAGMA integrity_check;"

# List config files in backup
tar -tzf /mnt/tank/backups/homelab/homeassistant/config-daily-20251025-2236.tar.gz | head -20
```

## Disaster Recovery

To restore Home Assistant on a new server:

1. Install Docker and Docker Compose
2. Copy compose.yml from `/mnt/fast/apps/homelab/home/`
3. Create directory: `mkdir -p /mnt/fast/apps/homelab/home/ha`
4. Restore databases and configs before first start
5. Start Home Assistant
6. Update DNS/reverse proxy
7. Re-pair Zigbee coordinator if needed (or restore zigbee.db to avoid re-pairing)

## Troubleshooting

### "Database is locked" error

```bash
# Ensure HA is stopped
docker compose down
docker ps | grep ha  # Should return nothing

# Then retry restore
```

### Zigbee devices not showing after restore

**If you restored zigbee.db**:
- Devices should appear automatically
- Check Settings → Devices & Services → Zigbee Home Automation
- Coordinator must be the same hardware (or same IEEE address)

**If you didn't restore zigbee.db**:
- You'll need to re-pair all Zigbee devices
- This is why backing up zigbee.db is important!

### Automations not working after restore

1. Check YAML syntax:
   ```bash
   docker exec ha python -m homeassistant --script check_config --config /config
   ```

2. Check logs:
   ```bash
   docker logs ha | grep -i error
   ```

3. Reload automations:
   - Go to Developer Tools → YAML → Reload Automations

### Permission errors

```bash
# Fix all permissions
sudo chown -R root:root /mnt/fast/apps/homelab/home/ha/
sudo chmod 644 /mnt/fast/apps/homelab/home/ha/*.db
sudo chmod 644 /mnt/fast/apps/homelab/home/ha/*.yaml
```

## Important Notes

- **Main database size**: Can be large (182MB in compressed backup, varies with history retention)
- **Zigbee database critical**: Contains device pairings - losing this means re-pairing all devices (888KB)
- **Backup method**: Uses Python SQLite Online Backup API (safe while HA is running)
- **History retention**: Main database size depends on recorder settings in configuration.yaml
- **.storage excluded**: The `.storage/` directory is excluded (cache/temp data)
- **deps excluded**: Python dependencies are excluded (regenerated on startup)

## Migration to New Hardware

When moving to new Zigbee coordinator hardware:

1. **Do NOT restore zigbee.db** - it's tied to specific hardware
2. Restore main database and configs
3. Re-pair all Zigbee devices with new coordinator
4. Update device IDs in automations if needed
