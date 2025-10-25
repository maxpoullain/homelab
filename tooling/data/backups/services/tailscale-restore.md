# Tailscale Restore Guide

This guide explains how to restore Tailscale from backups located in `/mnt/tank/backups/homelab/tailscale/`.

## Backup Files

- `state-[type]-[date].tar.gz` - Tailscale state (machine identity, configuration)

## What's Included

- `tailscaled.state` - Machine identity and connection state
- Configuration files
- DERP map cache

## What's Excluded

- Log files (*.log*, *.txt)

## Quick Restore

### 1. Stop Tailscale

```bash
cd /mnt/fast/apps/homelab/tailscale
docker compose down
```

### 2. Restore State Files

```bash
# Choose your backup file
BACKUP_FILE="/mnt/tank/backups/homelab/tailscale/state-daily-20251025-2236.tar.gz"

# Remove current state (optional - creates backup first)
if [ -d "/mnt/fast/apps/homelab/tailscale/tailscale-data" ]; then
  mv /mnt/fast/apps/homelab/tailscale/tailscale-data \
     /mnt/fast/apps/homelab/tailscale/tailscale-data.backup.$(date +%Y%m%d)
fi

# Extract backup
tar -xzf "$BACKUP_FILE" -C /mnt/fast/apps/homelab/tailscale/

# Fix permissions
sudo chown -R root:root /mnt/fast/apps/homelab/tailscale/tailscale-data/
```

### 3. Start Tailscale

```bash
cd /mnt/fast/apps/homelab/tailscale
docker compose up -d
```

### 4. Verify Restore

```bash
# Check Tailscale status
docker exec tailscale tailscale status

# Check IP address
docker exec tailscale tailscale ip

# Check logs
docker logs tailscale

# Verify connectivity
docker exec tailscale tailscale ping other-device-name
```

## When You Need This Restore

Common scenarios for restoring Tailscale state:

1. **Server rebuild**: Moving to new hardware with same hostname
2. **Accidental removal**: Accidentally removed from tailnet
3. **State corruption**: Tailscaled.state file corrupted
4. **Configuration rollback**: Need to restore previous configuration

## Alternative: Re-authentication

⚠️ **Note**: In most cases, it's easier to just re-authenticate Tailscale rather than restore from backup:

```bash
# Remove from admin console
# Visit https://login.tailscale.com/admin/machines
# Delete the old machine entry

# Start fresh
cd /mnt/fast/apps/homelab/tailscale
docker compose down
rm -rf tailscale-data/
docker compose up -d

# Re-authenticate
docker exec tailscale tailscale up --authkey tskey-auth-...
```

## Verify Backup Before Restore

```bash
# List contents
tar -tzf /mnt/tank/backups/homelab/tailscale/state-daily-20251025-2236.tar.gz

# Check for tailscaled.state file
tar -tzf /mnt/tank/backups/homelab/tailscale/state-daily-20251025-2236.tar.gz | grep tailscaled.state

# Extract to temp location for inspection
mkdir /tmp/ts-test
tar -xzf /mnt/tank/backups/homelab/tailscale/state-daily-20251025-2236.tar.gz -C /tmp/ts-test/
ls -lah /tmp/ts-test/tailscale-data/
```

## Partial Restore

### Restore Only State File

If you only need the machine identity:

```bash
# Extract just the state file
tar -xzf /mnt/tank/backups/homelab/tailscale/state-daily-20251025-2236.tar.gz \
  -C /tmp/ \
  tailscale-data/tailscaled.state

# Copy to Tailscale directory
cp /tmp/tailscale-data/tailscaled.state \
   /mnt/fast/apps/homelab/tailscale/tailscale-data/

sudo chown root:root /mnt/fast/apps/homelab/tailscale/tailscale-data/tailscaled.state
```

## Disaster Recovery

To restore Tailscale on a completely new server:

### Option 1: Restore from Backup (Preserve Machine Identity)

```bash
# 1. Install Docker and Docker Compose
# 2. Copy compose.yml from /mnt/fast/apps/homelab/tailscale/
# 3. Extract backup
tar -xzf /mnt/tank/backups/homelab/tailscale/state-daily-20251025-2236.tar.gz \
  -C /mnt/fast/apps/homelab/tailscale/
# 4. Start Tailscale
docker compose up -d
```

**Pros**: Same machine name and IP in tailnet  
**Cons**: Requires valid backup, complexity

### Option 2: Fresh Setup (Easier)

```bash
# 1. Start fresh
docker compose up -d

# 2. Authenticate with auth key or login URL
docker exec tailscale tailscale up

# 3. Follow authentication flow
```

**Pros**: Simpler, always works  
**Cons**: New machine identity, different IP

## Troubleshooting

### Machine not appearing in tailnet after restore

**Possible causes**:
1. Machine was removed from admin console
2. State file is from a machine that was deleted
3. Auth key expired

**Solutions**:
```bash
# Check Tailscale status
docker logs tailscale

# Try re-authentication
docker exec tailscale tailscale up

# If that doesn't work, start fresh (see Alternative above)
```

### "Bad state" or corruption errors

```bash
# Remove corrupted state
rm /mnt/fast/apps/homelab/tailscale/tailscale-data/tailscaled.state

# Try an older backup
tar -xzf /mnt/tank/backups/homelab/tailscale/state-weekly-20251018-0000.tar.gz \
  -C /mnt/fast/apps/homelab/tailscale/

# Or start fresh
docker compose down
rm -rf tailscale-data/
docker compose up -d
docker exec tailscale tailscale up
```

### Permission errors

```bash
sudo chown -R root:root /mnt/fast/apps/homelab/tailscale/tailscale-data/
sudo chmod 700 /mnt/fast/apps/homelab/tailscale/tailscale-data/
sudo chmod 600 /mnt/fast/apps/homelab/tailscale/tailscale-data/tailscaled.state
```

## Important Notes

- **Machine Identity**: The state file contains the machine's unique identity in your tailnet
- **IP Preservation**: Restoring state preserves the machine's Tailscale IP address
- **Not Critical**: Unlike databases, Tailscale state can be easily regenerated by re-authenticating
- **Backup Purpose**: Mainly useful for preserving machine name/IP during server rebuilds
- **Small Size**: State backups are typically under 1MB
- **Quick to regenerate**: Re-authentication takes < 1 minute

## Best Practice

**For most scenarios**: Don't restore from backup, just re-authenticate:
1. Faster
2. Simpler
3. Always works
4. Gets fresh configuration from Tailscale servers

**Use backup restore when**: You specifically need to preserve the exact machine identity and IP address.
