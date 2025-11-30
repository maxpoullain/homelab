# AdGuard Home Restore Guide

Restore AdGuard Home configuration, filters, and statistics database.

## What's Backed Up

- **AdGuardHome.yaml** - Main configuration file (DNS settings, filters, clients, rewrites)
- **Filters** - Custom filter lists and blocklists
- **Statistics database** - DNS query statistics and blocked domains
- **User data** - Configured clients, DNS rewrites, custom rules

**Excluded from backup:**
- `sessions.db` - Temporary web UI sessions (not needed)
- `querylog.json*` - Large query log files (can be regenerated)

## Backup Location

```
/mnt/tank/backups/homelab/adguard/
├── full-twice-daily-20251113-0700.tar.gz
├── full-daily-20251112-1900.tar.gz
├── full-weekly-20251110-1900.tar.gz
└── full-monthly-20251101-1900.tar.gz
```

## Quick Restore

### 1. Stop AdGuard Container

```bash
cd /mnt/fast/apps/homelab/adguard
docker compose stop adguard
```

### 2. Backup Current Data (Optional but Recommended)

```bash
# Only if you want to keep current state
sudo mv /mnt/fast/apps/homelab/adguard /mnt/fast/apps/homelab/adguard.old
```

### 3. Extract Backup

```bash
# Create directory
sudo mkdir -p /mnt/fast/apps/homelab/adguard

# Extract the backup (choose the appropriate backup file)
sudo tar -xzf /mnt/tank/backups/homelab/adguard/full-daily-YYYYMMDD-HHMM.tar.gz \
  -C /mnt/fast/apps/homelab/
```

### 4. Fix Permissions

```bash
sudo chown -R root:root /mnt/fast/apps/homelab/adguard
sudo chmod -R 755 /mnt/fast/apps/homelab/adguard
```

### 5. Start AdGuard

```bash
cd /mnt/fast/apps/homelab/adguard
docker compose up -d adguard
```

### 6. Verify Restore

```bash
# Check logs
docker logs adguard -f

# Access web UI
# https://adguard.corsair.tf

# Verify:
# - DNS settings are correct
# - Filters are loaded
# - Statistics are present (if they were in the backup)
# - Clients and DNS rewrites are configured
```

## What to Expect After Restore

- ✅ All DNS settings restored
- ✅ Filter lists and blocklists intact
- ✅ Custom DNS rewrites and client configurations
- ✅ Statistics database restored (historical data)
- ✅ Admin credentials preserved
- ⚠️ Query logs not restored (excluded to save space)

## Troubleshooting

### Container Won't Start

If AdGuard fails to start:

1. **Check configuration syntax**:
   ```bash
   cat /mnt/fast/apps/homelab/adguard/conf/AdGuardHome.yaml
   ```

2. **Check container logs**:
   ```bash
   docker logs adguard
   ```

3. **Verify permissions**:
   ```bash
   ls -la /mnt/fast/apps/homelab/adguard/
   sudo chown -R root:root /mnt/fast/apps/homelab/adguard
   ```

### Port 53 Conflicts

If port 53 is already in use:

```bash
# Check what's using port 53
sudo lsof -i :53
sudo netstat -tulpn | grep :53

# If systemd-resolved is running
sudo systemctl stop systemd-resolved
sudo systemctl disable systemd-resolved

# Remove symlink and create resolv.conf
sudo rm /etc/resolv.conf
echo "nameserver 1.1.1.1" | sudo tee /etc/resolv.conf
```

### Can't Access Web UI

1. **Check container is running**:
   ```bash
   docker ps | grep adguard
   ```

2. **Verify Traefik routing**:
   ```bash
   docker logs traefik | grep adguard
   ```

3. **Check network_mode is host**:
   ```bash
   docker inspect adguard | grep NetworkMode
   ```

### Filters Not Working

If blocklists aren't loading:

1. **Update filters manually** via web UI:
   - Settings → DNS blocklists → Update

2. **Check filter URLs** are accessible:
   ```bash
   curl -I https://adguard.com/en/filter-rules.html
   ```

3. **Restart container**:
   ```bash
   docker compose restart adguard
   ```

### Statistics Not Showing

If statistics are missing after restore:

1. **Check stats database exists**:
   ```bash
   ls -la /mnt/fast/apps/homelab/adguard/work/data/
   ```

2. **Statistics may have been cleared** - This is normal if retention period expired

3. **Configure statistics retention**:
   - Settings → General settings → Statistics configuration

## Disaster Recovery

### Scenario: Complete Loss of AdGuard Data

If you lose all data but have backups:

1. **Stop container** (if running)
2. **Remove old data**:
   ```bash
   sudo rm -rf /mnt/fast/apps/homelab/adguard
   ```
3. **Follow Quick Restore steps above**
4. **All settings, filters, and clients will be restored**

### Scenario: Partial Restore (Config Only)

If you only need to restore the configuration file:

```bash
# Extract just AdGuardHome.yaml
sudo tar -xzf /mnt/tank/backups/homelab/adguard/full-daily-YYYYMMDD-HHMM.tar.gz \
  -C /tmp/ adguard/conf/AdGuardHome.yaml

# Copy to target
sudo cp /tmp/adguard/conf/AdGuardHome.yaml /mnt/fast/apps/homelab/adguard/conf/

# Fix ownership
sudo chown root:root /mnt/fast/apps/homelab/adguard/conf/AdGuardHome.yaml

# Restart
docker compose restart adguard
```

### Scenario: Lost Admin Password

If you've lost the admin password and need to reset:

1. **Stop container**:
   ```bash
   docker compose stop adguard
   ```

2. **Edit AdGuardHome.yaml** and remove the users section:
   ```bash
   sudo nano /mnt/fast/apps/homelab/adguard/conf/AdGuardHome.yaml
   # Remove or comment out the 'users:' section
   ```

3. **Start container**:
   ```bash
   docker compose up -d adguard
   ```

4. **Complete initial setup wizard again** to set new credentials

## Migration to New Server

To move AdGuard to a new server:

1. **On old server**: Backup is already automated
2. **On new server**: 
   - Install AdGuard via compose
   - Stop container
   - Restore backup as described above
   - Update DNS settings on router/devices to point to new IP
   - Start container

**Important**: Update router DHCP DNS settings to new server IP.

## Backup Validation

Verify your backup contains all critical files:

```bash
# List contents of backup
tar -tzf /mnt/tank/backups/homelab/adguard/full-daily-YYYYMMDD-HHMM.tar.gz

# Should include:
# adguard/conf/AdGuardHome.yaml
# adguard/work/data/ (statistics)
```

## Configuration After Restore

After restoring, verify these settings:

1. **Upstream DNS servers** - Settings → DNS settings
2. **Filter lists** - Settings → DNS blocklists (update if needed)
3. **Client configurations** - Settings → Client settings
4. **DNS rewrites** - Filters → DNS rewrites
5. **Network settings** - Settings → General settings

## Testing After Restore

Verify DNS is working correctly:

```bash
# Test DNS resolution
dig @<your-server-ip> google.com
nslookup google.com <your-server-ip>

# Test ad blocking (should be blocked)
dig @<your-server-ip> ads.google.com

# Check from client device
nslookup google.com
```

## Important Notes

- **Query logs are excluded** from backups to save space (can be large)
- **Sessions.db is excluded** - temporary data, will regenerate
- **Filter updates** may be needed after restore if lists have updated
- **Statistics are preserved** if within retention period
- **Admin credentials** are restored from backup
- **Backup retention**: Daily for 7 days, weekly for 28 days, monthly for 180 days

## Related Services

AdGuard Home is standalone but may interact with:
- **Router DHCP**: Configure router to use AdGuard as DNS
- **Traefik**: Web UI is accessed via Traefik reverse proxy
- **Network devices**: All devices use AdGuard for DNS resolution

## Support

For issues:

1. Check AdGuard logs: `docker logs adguard`
2. Verify configuration: `cat /mnt/fast/apps/homelab/adguard/conf/AdGuardHome.yaml`
3. Check AdGuard documentation: https://github.com/AdguardTeam/AdGuardHome/wiki
4. Test DNS resolution: `dig @<server-ip> google.com`
5. Verify port 53 is not blocked by firewall
