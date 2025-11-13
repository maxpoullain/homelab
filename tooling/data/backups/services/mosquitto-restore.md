# Mosquitto Restore Guide

This guide explains how to restore Mosquitto (MQTT broker) from backups located in `/mnt/tank/backups/homelab/mosquitto/`.

## Backup Files

- `config-[type]-[date].tar.gz` - Configuration files (mosquitto.conf)

## Quick Restore

### 1. Stop Mosquitto

```bash
cd /mnt/fast/apps/homelab/home
docker compose stop mosquitto
```

### 2. Restore Configuration

```bash
# Choose your backup timestamp
BACKUP_DATE="daily-20251113-1900"
BACKUP_DIR="/mnt/tank/backups/homelab/mosquitto"
MOSQUITTO_DIR="/mnt/fast/apps/homelab/home/mosquitto"

# Backup current config (optional)
tar -czf "$MOSQUITTO_DIR/config-backup-$(date +%Y%m%d-%H%M).tar.gz" -C "$MOSQUITTO_DIR" config

# Restore config
tar -xzf "$BACKUP_DIR/config-$BACKUP_DATE.tar.gz" -C "$MOSQUITTO_DIR/"

# Fix permissions
sudo chown -R 3000:3002 "$MOSQUITTO_DIR/config"
```

### 3. Start Mosquitto

```bash
cd /mnt/fast/apps/homelab/home
docker compose start mosquitto
```

### 4. Verify Restore

```bash
# Check logs
docker logs mosquitto

# Test MQTT connection
docker exec mosquitto mosquitto_sub -h localhost -t '#' -v -C 1
```

## Important Notes

- **Minimal impact**: Mosquitto config is small and rarely changes
- **No persistent data**: MQTT is a message broker; messages are stored by subscribers (like Home Assistant)
- **Config location**: `/mosquitto/config/mosquitto.conf`
- **Permissions**: Must be owned by PUID:3000, PGID:3002
- **Dependencies**: Required by Home Assistant and Zigbee2mqtt

## Disaster Recovery

To restore Mosquitto on a new server:

1. Install Docker and Docker Compose
2. Copy compose.yml from `/mnt/fast/apps/homelab/home/`
3. Create directory: `mkdir -p /mnt/fast/apps/homelab/home/mosquitto/{config,data,log}`
4. Restore configuration before first start
5. Start Mosquitto
6. Verify clients (HA, Zigbee2mqtt) can connect

## Troubleshooting

### Permission errors

```bash
# Fix permissions
sudo chown -R 3000:3002 /mnt/fast/apps/homelab/home/mosquitto/
```

### Connection refused from clients

```bash
# Check Mosquitto is running
docker ps | grep mosquitto

# Check logs for errors
docker logs mosquitto

# Test local connection
docker exec mosquitto mosquitto_sub -h localhost -t test -v
```

### Port conflicts

```bash
# Check if port 1883 is in use
sudo netstat -tlnp | grep 1883

# Verify correct port mapping in compose.yml
docker compose config | grep -A5 mosquitto
```

## Migration Notes

When moving to a new server:

1. Restore mosquitto.conf
2. Update any hardcoded IPs or hostnames
3. Ensure clients (HA, Z2M) use correct broker address
4. Test connectivity from all MQTT clients
