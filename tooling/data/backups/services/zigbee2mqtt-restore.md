# Zigbee2mqtt Restore Guide

Restore Zigbee2mqtt configuration, device database, and coordinator backup.

## What's Backed Up

- **configuration.yaml** - Network keys, device mappings, MQTT settings
- **database.db** - Device state, pairings, and history
- **coordinator_backup.json** - Zigbee coordinator backup
- **configuration_backup_v*.yaml** - Previous configuration versions

**Critical**: These files contain your entire Zigbee network configuration. Without them, you'll need to re-pair all Zigbee devices.

## Backup Location

```
/mnt/tank/backups/homelab/zigbee2mqtt/
├── full-twice-daily-20251113-0700.tar.gz
├── full-daily-20251112-1900.tar.gz
├── full-weekly-20251110-1900.tar.gz
└── full-monthly-20251101-1900.tar.gz
```

## Quick Restore

### 1. Stop Zigbee2mqtt Container

```bash
cd /mnt/fast/apps/homelab/home
docker compose stop zigbee2mqtt
```

### 2. Backup Current Data (Optional but Recommended)

```bash
# Only if you want to keep current state
sudo mv /mnt/fast/apps/homelab/home/zigbee2mqtt /mnt/fast/apps/homelab/home/zigbee2mqtt.old
```

### 3. Extract Backup

```bash
# Create directory
sudo mkdir -p /mnt/fast/apps/homelab/home/zigbee2mqtt

# Extract the backup (choose the appropriate backup file)
sudo tar -xzf /mnt/tank/backups/homelab/zigbee2mqtt/full-daily-YYYYMMDD-HHMM.tar.gz \
  -C /mnt/fast/apps/homelab/home/
```

### 4. Fix Permissions

```bash
sudo chown -R 1000:1000 /mnt/fast/apps/homelab/home/zigbee2mqtt
```

### 5. Start Zigbee2mqtt

```bash
cd /mnt/fast/apps/homelab/home
docker compose up -d zigbee2mqtt
```

### 6. Verify Restore

```bash
# Check logs
docker logs zigbee2mqtt -f

# Verify devices are visible
# Access Zigbee2mqtt UI: http://your-server:8080
# Check that all your devices appear
```

## What to Expect After Restore

- ✅ All device pairings restored
- ✅ Device names and configurations intact
- ✅ Network keys and security restored
- ✅ Coordinator state restored
- ✅ MQTT configuration restored

## Troubleshooting

### Devices Not Responding

If devices show up but aren't responding:

1. **Power cycle the coordinator**: Unplug and replug the USB stick
2. **Restart the container**:
   ```bash
   docker compose restart zigbee2mqtt
   ```
3. **Check Zigbee network health** in the UI

### Coordinator Not Starting

If the coordinator fails to start:

1. **Check USB device path**:
   ```bash
   ls -l /dev/serial/by-id/
   ```
2. **Verify compose.yml** has correct device mapping
3. **Check container logs**:
   ```bash
   docker logs zigbee2mqtt
   ```

### Configuration Errors

If there are configuration errors:

1. **Check configuration.yaml syntax**:
   ```bash
   cat /mnt/fast/apps/homelab/home/zigbee2mqtt/configuration.yaml
   ```
2. **Use a backup version if needed**:
   ```bash
   cd /mnt/fast/apps/homelab/home/zigbee2mqtt
   cp configuration_backup_v2.yaml configuration.yaml
   ```

### Permissions Issues

```bash
# Fix ownership
sudo chown -R 1000:1000 /mnt/fast/apps/homelab/home/zigbee2mqtt

# Fix permissions
sudo chmod -R 755 /mnt/fast/apps/homelab/home/zigbee2mqtt
sudo chmod 644 /mnt/fast/apps/homelab/home/zigbee2mqtt/configuration.yaml
sudo chmod 644 /mnt/fast/apps/homelab/home/zigbee2mqtt/database.db
```

## Disaster Recovery

### Scenario: Complete Loss of Zigbee2mqtt Data

If you lose all data but have backups:

1. **Stop container** (if running)
2. **Remove old data**:
   ```bash
   sudo rm -rf /mnt/fast/apps/homelab/home/zigbee2mqtt
   ```
3. **Follow Quick Restore steps above**
4. **Verify coordinator backup is loaded**:
   - Check logs for "Coordinator backup restored"
5. **All devices should reconnect automatically**

### Scenario: Coordinator Hardware Failure

If you need to replace the Zigbee coordinator USB stick:

1. **Install new coordinator**
2. **Restore backup as above**
3. **On first start, coordinator will restore from coordinator_backup.json**
4. **Devices may need a few minutes to reconnect**
5. **If devices don't reconnect, you may need to re-pair them**

**Note**: Coordinator backup helps but doesn't guarantee device re-pairing will work with new hardware.

### Scenario: Partial Restore (Config Only)

If you only need to restore the configuration:

```bash
# Extract just configuration.yaml
sudo tar -xzf /mnt/tank/backups/homelab/zigbee2mqtt/full-daily-YYYYMMDD-HHMM.tar.gz \
  -C /tmp/ zigbee2mqtt/configuration.yaml

# Copy to target
sudo cp /tmp/zigbee2mqtt/configuration.yaml /mnt/fast/apps/homelab/home/zigbee2mqtt/

# Fix ownership
sudo chown 1000:1000 /mnt/fast/apps/homelab/home/zigbee2mqtt/configuration.yaml

# Restart
docker compose restart zigbee2mqtt
```

## Migration to New Server

To move Zigbee2mqtt to a new server:

1. **On old server**: Backup is already automated
2. **On new server**: 
   - Install Zigbee2mqtt via compose
   - Stop container
   - Restore backup as described above
   - **Move the USB coordinator stick** to the new server
   - Update device path in compose.yml if needed
   - Start container

**Critical**: The coordinator USB stick must move with the data, or devices won't be paired.

## Backup Validation

Verify your backup contains all critical files:

```bash
# List contents of backup
tar -tzf /mnt/tank/backups/homelab/zigbee2mqtt/full-daily-YYYYMMDD-HHMM.tar.gz

# Should include:
# zigbee2mqtt/configuration.yaml
# zigbee2mqtt/database.db
# zigbee2mqtt/coordinator_backup.json
# zigbee2mqtt/configuration_backup_v*.yaml
```

## Related Services

- **Home Assistant**: Uses Zigbee2mqtt for Zigbee device control
- **Mosquitto**: MQTT broker that Zigbee2mqtt connects to (not backed up - ephemeral data only)

If both services are down, restore in this order:
1. Mosquitto (start - no restore needed)
2. Zigbee2mqtt (restore as above)
3. Home Assistant (see homeassistant-restore.md)

## Important Notes

- **Network keys are critical**: Without them, you'll need to re-pair all devices
- **Coordinator backup helps**: But may not prevent re-pairing with new hardware
- **Regular backups essential**: Device re-pairing is time-consuming
- **Backup retention**: Daily for 7 days, weekly for 28 days, monthly for 180 days
- **Mosquitto not backed up**: It's just a message broker with ephemeral data
- **Test restores**: Periodically verify your backups are complete

## Support

For issues:

1. Check Zigbee2mqtt logs: `docker logs zigbee2mqtt`
2. Verify USB coordinator is detected: `ls -l /dev/serial/by-id/`
3. Check Zigbee2mqtt documentation: https://www.zigbee2mqtt.io/
4. Review configuration.yaml for errors
5. Check Home Assistant integration if devices don't appear
