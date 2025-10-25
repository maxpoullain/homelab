# Homelab Services Backup System

Comprehensive backup solution for all homelab services, organized by service rather than backup method.

## Quick Start

### Run Backup Manually

```bash
sudo /mnt/fast/apps/homelab/tooling/data/backups/backup-services.sh
```

### Check Backup Status

```bash
sudo /mnt/fast/apps/homelab/tooling/data/backups/backup-check.sh
```

### View Backup Log

```bash
tail -f /mnt/fast/apps/homelab/tooling/data/backups/backup-services.log
```

## Architecture

### One Script, All Services

**`backup-services.sh`** - Main backup script that backs up all 7 services:

1. **Immich** - PostgreSQL database + storage files (library/upload/profile)
2. **Vaultwarden** - SQLite database + RSA keys + attachments  
3. **OtterWiki** - SQLite database
4. **Home Assistant** - SQLite databases (main + zigbee) + YAML configs
5. **Jellyfin** - Full backup (databases + metadata + plugins + settings)
6. **Tailscale** - State files
7. **Traefik** - SSL/TLS certificates (ACME)

### Organized by Service

Backup files are stored in `/mnt/tank/backups/homelab/[service]/`

Restore documentation is tracked in git at `tooling/data/backups/services/`:

```
Backup Files:
/mnt/tank/backups/homelab/
├── immich/
│   ├── db-[type]-[date].sql.gz           # PostgreSQL database
│   └── storage-[type]-[date].tar.gz      # Storage files
├── vaultwarden/
│   ├── db-[type]-[date].sqlite3          # Database
│   ├── rsa_key-[type]-[date].pem         # RSA key
│   └── attachments-[type]-[date].tar.gz  # Attachments
├── wiki/
│   └── db-[type]-[date].sqlite3
├── homeassistant/
│   ├── db-[type]-[date].sqlite3          # Main database
│   ├── zigbee-[type]-[date].sqlite3      # Zigbee database
│   └── config-[type]-[date].tar.gz       # YAML configs
├── jellyfin/
│   └── full-[type]-[date].tar.gz         # Full backup
├── tailscale/
│   └── state-[type]-[date].tar.gz
└── traefik/
    └── acme-[type]-[date].tar.gz         # SSL certificates

Restore Documentation (in git):
tooling/data/backups/services/
├── immich-restore.md
├── vaultwarden-restore.md
├── otterwiki-restore.md
├── homeassistant-restore.md
├── jellyfin-restore.md
├── tailscale-restore.md
└── traefik-restore.md
```

## Backup Types & Retention

Backups are automatically categorized by time:

| Type | When | Retention | Frequency |
|------|------|-----------|-----------|
| **twice-daily** | 7 AM & 7 PM | 3 days | 6 backups total |
| **daily** | Midnight | 7 days | 7 backups |
| **weekly** | Sunday midnight | 28 days | 4 backups |
| **monthly** | 1st of month, midnight | 180 days | 6 backups |

Example filenames:
- `db-twice-daily-20251025-1900.sql.gz`
- `db-daily-20251025-0000.sql.gz`
- `db-weekly-20251027-0000.sql.gz`
- `db-monthly-20251101-0000.sql.gz`

## Backup Methods by Service

### Immich
- **Database**: PostgreSQL `pg_dumpall` with `--clean --if-exists`
- **Storage**: Tar of library/upload/profile (excludes 30GB of regenerable content)
- **Method**: Safe while running

### Vaultwarden
- **Database**: Built-in `/vaultwarden backup` command
- **Keys/Attachments**: Docker cp
- **Method**: Safe while running

### OtterWiki
- **Database**: Python SQLite Online Backup API
- **Method**: Safe while running, no locking

### Home Assistant
- **Databases**: Python SQLite Online Backup API (main + zigbee)
- **Configs**: Tar of YAML files
- **Method**: Safe while running

### Jellyfin
- **Full backup**: Tar of entire config directory
- **Includes**: Databases, metadata, plugins, settings
- **Excludes**: Cache, logs, transcodes
- **Method**: Direct file copy (no dedicated DB tool available)

### Tailscale
- **State files**: Tar of tailscale-data directory
- **Method**: File backup (excludes logs)

### Traefik
- **Certificates**: Tar of acme directory
- **Contains**: All Let's Encrypt SSL certificates
- **Method**: File backup

## Setup

### 1. Create Cron Job (TrueNAS GUI)

**Via TrueNAS SCALE Web Interface:**

1. Go to: **System → Advanced → Cron Jobs**
2. Click **Add**
3. Configure:
   - **Description**: Homelab Services Backup
   - **Command**: `/mnt/fast/apps/homelab/tooling/data/backups/backup-services.sh`
   - **Run As User**: `root`
   - **Schedule**: 
     - **Minutes**: `0`
     - **Hours**: `7,19` (7 AM and 7 PM)
     - **Days of Month**: `*`
     - **Months**: `*`
     - **Days of Week**: `*`
   - **Hide Standard Output**: ✓ (checked)
   - **Hide Standard Error**: ☐ (unchecked - to see errors)
4. Click **Save**

### 2. Test Backup

```bash
# Run manually first
sudo /mnt/fast/apps/homelab/tooling/data/backups/backup-services.sh

# Check results
sudo /mnt/fast/apps/homelab/tooling/data/backups/backup-check.sh

# View log
tail -50 /mnt/fast/apps/homelab/tooling/data/backups/backup-services.log
```

### 3. Verify Cron Job

```bash
# Check if configured
sudo /mnt/fast/apps/homelab/tooling/data/backups/backup-check.sh

# Or check directly
midclt call cronjob.query | grep backup-services
```

## Restore

Each service has its own restore guide in `tooling/data/backups/services/`:

```bash
# View restore guide for specific service
cat /mnt/fast/apps/homelab/tooling/data/backups/services/immich-restore.md
cat /mnt/fast/apps/homelab/tooling/data/backups/services/vaultwarden-restore.md
cat /mnt/fast/apps/homelab/tooling/data/backups/services/homeassistant-restore.md
# ... etc
```

Or view them in your editor/git repository.

## Monitoring

### Check Status

```bash
# Full status report
sudo /mnt/fast/apps/homelab/tooling/data/backups/backup-check.sh
```

Shows:
- Cron job configuration status
- Container running status (all 7 services)
- Last backup times per service
- Backup file counts
- Backup set integrity validation
- Total backup sizes

### View Logs

```bash
# Last 50 lines
tail -50 /mnt/fast/apps/homelab/tooling/data/backups/backup-services.log

# Follow live
tail -f /mnt/fast/apps/homelab/tooling/data/backups/backup-services.log

# Search for errors
grep -i error /mnt/fast/apps/homelab/tooling/data/backups/backup-services.log

# View specific backup run
grep "Date: 2025-10-25" /mnt/fast/apps/homelab/tooling/data/backups/backup-services.log -A 100
```

### Success/Failure Tracking

The script tracks each service individually:

```bash
# View summary from last run
tail -30 /mnt/fast/apps/homelab/tooling/data/backups/backup-services.log | grep -A 10 "Backup Summary"
```

Output example:
```
Status by service:
Immich: ✓ SUCCESS
Vaultwarden: ✓ SUCCESS
OtterWiki: ✓ SUCCESS
Home Assistant: ✓ SUCCESS
Jellyfin: ✓ SUCCESS
Tailscale: ✓ SUCCESS
Traefik: ⚠ SKIPPED

Results: 6 successful, 0 failed (out of 7)
```

## Troubleshooting

### Backup Failed for a Service

1. Check the log for details:
   ```bash
   tail -100 /mnt/fast/apps/homelab/tooling/data/backups/backup-services.log | grep -A 20 "ServiceName"
   ```

2. Verify container is running:
   ```bash
   docker ps | grep service-name
   ```

3. Check container logs:
   ```bash
   docker logs service-name
   ```

4. Test backup manually:
   ```bash
   sudo /mnt/fast/apps/homelab/tooling/data/backups/backup-services.sh
   ```

### Disk Space Issues

Check backup sizes:
```bash
du -sh /mnt/tank/backups/homelab/*
du -sh /mnt/tank/backups/homelab/
```

Largest consumers are typically:
- Immich storage (photos/videos)
- Home Assistant main database (history/states)

### Cron Job Not Running

1. Check cron configuration:
   ```bash
   midclt call cronjob.query | grep backup-services
   ```

2. Check cron service is running:
   ```bash
   systemctl status cron
   ```

3. Check for errors in syslog:
   ```bash
   grep backup-services /var/log/syslog
   ```

### Permission Issues

All backups run as root. If you see permission errors:

```bash
# Fix backup script permissions
sudo chmod +x /mnt/fast/apps/homelab/tooling/data/backups/backup-services.sh

# Fix backup directory permissions
sudo chown -R root:root /mnt/tank/backups/homelab/
sudo chmod -R 755 /mnt/tank/backups/homelab/
```

## Advanced

### Manual Backup of Single Service

The script backs up all services, but you can extract just one section if needed. Example for Immich:

```bash
# Run full script but only watch Immich section
sudo /mnt/fast/apps/homelab/tooling/data/backups/backup-services.sh 2>&1 | grep -A 20 "Backing up Immich"
```

### Custom Retention

Edit `/mnt/fast/apps/homelab/tooling/data/backups/backup-services.sh`:

```bash
# Around line 20-30
if [ "$DAY_OF_MONTH" = "01" ] && [ "$HOUR" = "00" ]; then
  BACKUP_TYPE="monthly"
  RETENTION_DAYS=180  # Change this
elif ...
```

### ZFS Snapshots (Recommended Additional Layer)

Backups are exported to `/mnt/tank/backups/homelab/`. Consider also:

1. **ZFS snapshots** of the tank dataset (instant, space-efficient)
2. **Off-site replication** to another location
3. **Cloud backup** for critical services

Example:
```bash
# Snapshot after each backup
zfs snapshot tank/backups@$(date +%Y%m%d-%H%M)

# Keep last 30 days
# (configure via TrueNAS GUI: Data Protection → Periodic Snapshot Tasks)
```

## Migration from Old Scripts

If you were using the previous `backup-dbs.sh` and `backup-apps.sh`:

1. **New unified script**: `/mnt/fast/apps/homelab/tooling/data/backups/backup-services.sh`
2. **Old scripts**: Can be deleted (they're now combined)
3. **Backup location**: Same - `/mnt/tank/backups/homelab/`
4. **File formats**: Same - compatible with old backups
5. **Cron job**: Update to use `backup-services.sh` instead

Update cron:
```bash
# Old: backup-dbs.sh and backup-apps.sh
# New: backup-services.sh (does both)
```

## File Locations

| Item | Path |
|------|------|
| Main backup script | `/mnt/fast/apps/homelab/tooling/data/backups/backup-services.sh` |
| Status check script | `/mnt/fast/apps/homelab/tooling/data/backups/backup-check.sh` |
| Log file | `/mnt/fast/apps/homelab/tooling/data/backups/backup-services.log` |
| Backup destination | `/mnt/tank/backups/homelab/` |
| Service restore guides | `/mnt/fast/apps/homelab/tooling/data/backups/services/` |

## Support

For issues or questions:

1. Check service-specific RESTORE.md files
2. Review backup logs
3. Verify container status and logs
4. Test manual backup run

## Notes

- **No volume mounts needed**: All backups use docker exec or docker cp
- **Safe while running**: All backup methods are safe to run while services are active
- **Atomic operations**: Failed backups are cleaned up automatically
- **Exit codes**: Script exits with code 1 if any service fails, 0 if all succeed
- **Log rotation**: Logs automatically rotate when they exceed 10MB
- **Backup validation**: Vaultwarden and Home Assistant backups validate integrity
