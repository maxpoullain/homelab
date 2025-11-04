# Homelab Services Backup System

Comprehensive backup solution for all homelab services and TrueNAS configuration.

## Quick Start

### Run Backups Manually

```bash
# Backup all homelab services
sudo /mnt/fast/apps/homelab/tooling/data/backups/backup-services.sh

# Backup specific services only
sudo /mnt/fast/apps/homelab/tooling/data/backups/backup-services.sh prowlarr sonarr radarr

# List available services
sudo /mnt/fast/apps/homelab/tooling/data/backups/backup-services.sh --list

# Show help
sudo /mnt/fast/apps/homelab/tooling/data/backups/backup-services.sh --help

# Backup TrueNAS configuration
sudo /mnt/fast/apps/homelab/tooling/data/backups/backup-truenas.sh
```

### Check Backup Status

```bash
sudo /mnt/fast/apps/homelab/tooling/data/backups/backup-check.sh
```

### View Backup Logs

```bash
tail -f /mnt/fast/apps/homelab/tooling/data/backups/backup-services.log
tail -f /mnt/fast/apps/homelab/tooling/data/backups/backup-truenas.log
```

## Architecture

### Two Main Scripts

#### 1. Services Backup (`backup-services.sh`)

Backs up all 11 homelab services:

1. **Immich** - PostgreSQL database + storage files (library/upload/profile)
2. **Vaultwarden** - SQLite database + RSA keys + attachments  
3. **OtterWiki** - SQLite database
4. **Home Assistant** - SQLite databases (main + zigbee) + YAML configs
5. **Jellyfin** - Full backup (databases + metadata + plugins + settings)
6. **Tailscale** - State files
7. **Traefik** - SSL/TLS certificates (ACME)
8. **Prowlarr** - Full backup (databases + config files)
9. **Sonarr** - Full backup (databases + config files)
10. **Radarr** - Full backup (databases + config files)
11. **Readarr** - Full backup (databases + config files)

#### 2. TrueNAS Config Backup (`backup-truenas.sh`)

Backs up TrueNAS system configuration:

1. **System config** - All TrueNAS settings, users, shares
2. **SSH keys** - Host keys (machine identity)
3. **SSL certificates** - Custom SSL certs (if any)
4. **ZFS configuration** - Pool structure and properties
5. **Network config** - IP addresses and netplan
6. **Cron jobs** - All scheduled tasks

### Organized by Service

```
/mnt/tank/backups/
├── homelab/              # Service backups
│   ├── immich/
│   │   ├── db-[type]-[date].sql.gz
│   │   └── storage-[type]-[date].tar.gz
│   ├── vaultwarden/
│   │   ├── db-[type]-[date].sqlite3
│   │   ├── rsa_key-[type]-[date].pem
│   │   └── attachments-[type]-[date].tar.gz
│   ├── wiki/
│   ├── homeassistant/
│   ├── jellyfin/
│   ├── tailscale/
│   ├── traefik/
│   ├── prowlarr/
│   │   └── full-[type]-[date].tar.gz
│   ├── sonarr/
│   │   └── full-[type]-[date].tar.gz
│   ├── radarr/
│   │   └── full-[type]-[date].tar.gz
│   └── readarr/
│       └── full-[type]-[date].tar.gz
└── truenas/              # TrueNAS config backups
    ├── daily-20251026-1800/
    │   ├── truenas-config.tar.gz
    │   ├── ssh-keys.tar.gz
    │   ├── ssl-certs.tar.gz
    │   ├── zfs-config.txt
    │   ├── network.txt
    │   └── cronjobs.json
    ├── weekly-20251027-0100/
    └── monthly-20251101-0100/

Restore Documentation (in git):
tooling/data/backups/services/
├── immich-restore.md
├── vaultwarden-restore.md
├── otterwiki-restore.md
├── homeassistant-restore.md
├── jellyfin-restore.md
├── tailscale-restore.md
├── traefik-restore.md
├── prowlarr-restore.md
├── sonarr-restore.md
├── radarr-restore.md
└── readarr-restore.md
```

## Backup Types & Retention

### Service Backups
Backups are automatically categorized by time:

| Type | When | Retention | Frequency |
|------|------|-----------|-----------|
| **twice-daily** | 7 AM | 3 days | 6 backups total |
| **daily** | 7 PM | 7 days | 7 backups |
| **weekly** | Sunday 7 PM | 28 days | 4 backups |
| **monthly** | 1st of month, 7 PM | 180 days | 6 backups |

### TrueNAS Config Backups
Stored in individual folders:

| Type | When | Retention | Frequency |
|------|------|-----------|-----------|
| **daily** | 1 AM | 7 days | 7 backup folders |
| **weekly** | Sunday 1 AM | 28 days | 4 backup folders |
| **monthly** | 1st of month, 1 AM | 90 days | 3 backup folders |

Example filenames:
- Service: `db-twice-daily-20251025-1900.sql.gz`
- TrueNAS: `daily-20251026-0100/` (folder with 6 files inside)

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

### Prowlarr
- **Full backup**: Tar of entire config directory
- **Includes**: Databases, config.xml, Definitions
- **Excludes**: Logs, built-in Backups folder
- **Method**: Direct file backup (same as Jellyfin)

### Sonarr
- **Full backup**: Tar of entire config directory
- **Includes**: Databases, config.xml
- **Excludes**: Logs, built-in Backups folder, MediaCover
- **Method**: Direct file backup (same as Jellyfin)

### Radarr
- **Full backup**: Tar of entire config directory
- **Includes**: Databases, config.xml
- **Excludes**: Logs, built-in Backups folder, MediaCover
- **Method**: Direct file backup (same as Jellyfin)

### Readarr
- **Full backup**: Tar of entire config directory
- **Includes**: Databases, config.xml
- **Excludes**: Logs, built-in Backups folder, MediaCover
- **Method**: Direct file backup (same as Jellyfin)

## TrueNAS Configuration Backup

Separate backup of TrueNAS OS configuration for disaster recovery:

### Components Backed Up (6 files per backup folder)

1. **truenas-config.tar.gz**: Complete system configuration
   - All system settings, shares, users, groups
   - From `/data/freenas-v1.db` and `/data/pwenc_secret`
   
2. **ssh-keys.tar.gz**: SSH host keys
   - Preserves server identity across reinstalls
   - From `/usr/local/etc/ssh/`

3. **ssl-certs.tar.gz**: Web UI SSL certificates
   - Custom certificates for TrueNAS web interface
   - From `/etc/certificates/`

4. **zfs-config.txt**: ZFS pool configuration
   - Output of `zpool status` for all pools
   - Reference for pool reconstruction

5. **network.txt**: Network configuration
   - Interfaces, VLANs, static routes, DNS
   - From `midclt call` network queries

6. **cronjobs.json**: Scheduled tasks
   - All cron jobs configured in TrueNAS
   - From `midclt call cronjob.query`

### Backup Organization

Each backup creates one folder containing all 6 files:
```
/mnt/tank/backups/truenas/
├── daily-20251026-0100/
│   ├── truenas-config.tar.gz
│   ├── ssh-keys.tar.gz
│   ├── ssl-certs.tar.gz
│   ├── zfs-config.txt
│   ├── network.txt
│   └── cronjobs.json
├── weekly-20251027-0100/
└── monthly-20251101-0100/
```

### Retention Policy

- **Daily**: 7 days (7 folders)
- **Weekly**: 28 days (4 folders)
- **Monthly**: 90 days (3 folders)

Typical size: ~700KB per backup folder

### Restoration Notes

See `TRUENAS-CRON-SETUP.md` for disaster recovery procedures using these backups.

---

## Setup

### 1. Create Cron Jobs (TrueNAS GUI)

**Via TrueNAS SCALE Web Interface:**

#### Services Backup (7 AM & 7 PM)

1. Go to: **System → Advanced → Cron Jobs**
2. Click **Add**
3. Configure:
   - **Description**: Homelab Services Backup (Twice Daily)
   - **Command**: `/mnt/fast/apps/homelab/tooling/data/backups/backup-services.sh`
   - **Run As User**: `root`
   - **Schedule**: 
     - **Minutes**: `0`
     - **Hours**: `7,19` (7 AM and 7 PM)
     - **Days**: `*` (all days)
   - **Hide Standard Output**: ☐ (unchecked)
   - **Hide Standard Error**: ☐ (unchecked)
4. Click **Save**

#### TrueNAS Config Backup (1 AM daily)

1. Click **Add** again
2. Configure:
   - **Description**: TrueNAS Configuration Backup (Daily)
   - **Command**: `/mnt/fast/apps/homelab/tooling/data/backups/backup-truenas.sh`
   - **Run As User**: `root`
   - **Schedule**: 
     - **Minutes**: `0`
     - **Hours**: `1` (1 AM)
     - **Days**: `*` (all days)
   - **Hide Standard Output**: ☐ (unchecked)
   - **Hide Standard Error**: ☐ (unchecked)
3. Click **Save**

### 2. Test Backups

```bash
# Test services backup
sudo /mnt/fast/apps/homelab/tooling/data/backups/backup-services.sh

# Test TrueNAS config backup
sudo /mnt/fast/apps/homelab/tooling/data/backups/backup-truenas.sh

# Check results
sudo /mnt/fast/apps/homelab/tooling/data/backups/backup-check.sh

# View logs
tail -50 /mnt/fast/apps/homelab/tooling/data/backups/backup-services.log
tail -50 /mnt/fast/apps/homelab/tooling/data/backups/backup-truenas.log
```

### 3. Setup Offsite Backup (B2 - Optional but Recommended)

**For cloud backup to Backblaze B2 (weekly + monthly only):**

1. **Tasks → Cloud Sync Tasks → Add**
2. Configure:
   - **Description**: Homelab Backups to B2 (Weekly/Monthly)
   - **Direction**: Push
   - **Transfer Mode**: Sync
   - **Credential**: (Your B2 credentials)
   - **Bucket**: Your B2 bucket name
   - **Folder**: `/homelab-backups/`
   - **Directory/Files**: `/mnt/tank/backups`
3. **Exclude patterns** (add one line):
   ```
   daily-*
   ```
4. **Schedule**: Daily at 2 AM (after backups complete)
   - **Minutes**: `0`
   - **Hours**: `2`

This will upload only weekly and monthly backups, saving costs (~$0.27/month).

### 4. Verify Cron Jobs

```bash
# Check if configured
sudo /mnt/fast/apps/homelab/tooling/data/backups/backup-check.sh

# Or check directly
midclt call cronjob.query | grep backup
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
# Full status report (services + TrueNAS config)
sudo /mnt/fast/apps/homelab/tooling/data/backups/backup-check.sh
```

Shows:
- Cron job configuration status (both scripts)
- Container running status (all 11 services)
- Last backup times per service
- Backup file counts
- Backup set integrity validation
- **TrueNAS config backup status and validation**
- Total backup sizes

### View Logs

```bash
# Services backup log - Last 50 lines
tail -50 /mnt/fast/apps/homelab/tooling/data/backups/backup-services.log

# TrueNAS config backup log - Last 50 lines
tail -50 /mnt/fast/apps/homelab/tooling/data/backups/backup-truenas.log

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
Prowlarr: ✓ SUCCESS
Sonarr: ✓ SUCCESS
Radarr: ✓ SUCCESS
Readarr: ✓ SUCCESS

Results: 10 successful, 0 failed (out of 11)
```

## Troubleshooting

### Service Backup Failed

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

### TrueNAS Config Backup Failed

1. Check the TrueNAS backup log:
   ```bash
   tail -100 /mnt/fast/apps/homelab/tooling/data/backups/backup-truenas.log
   ```

2. Verify backup folders exist:
   ```bash
   ls -lh /mnt/tank/backups/truenas/
   ```

3. Check if a folder is incomplete (should have 6 files):
   ```bash
   find /mnt/tank/backups/truenas/ -type d -name "*-*" -exec sh -c 'echo -n "$1: "; ls "$1" | wc -l' _ {} \;
   ```

4. Test backup manually:
   ```bash
   sudo /mnt/fast/apps/homelab/tooling/data/backups/backup-truenas.sh
   ```

### Disk Space Issues

Check backup sizes:
```bash
# Service backups
du -sh /mnt/tank/backups/homelab/*
du -sh /mnt/tank/backups/homelab/

# TrueNAS config backups (usually minimal)
du -sh /mnt/tank/backups/truenas/*
du -sh /mnt/tank/backups/truenas/

# Total
du -sh /mnt/tank/backups/
```

Largest consumers are typically:
- Immich storage (photos/videos)
- Home Assistant main database (history/states)
- TrueNAS backups are minimal (<1MB per folder)

### Cron Job Not Running

1. Check cron configuration (both jobs):
   ```bash
   midclt call cronjob.query | grep backup
   ```

2. You should see two jobs:
   - backup-services.sh at 7 AM & 7 PM
   - backup-truenas.sh at 1 AM

3. Check for errors in syslog:
   ```bash
   grep backup /var/log/syslog
   ```

4. Verify scripts are executable:
   ```bash
   ls -l /mnt/fast/apps/homelab/tooling/data/backups/backup-*.sh
   ```

### Permission Issues

All backups run as root. If you see permission errors:

```bash
# Fix service backup script permissions
sudo chmod +x /mnt/fast/apps/homelab/tooling/data/backups/backup-services.sh
sudo chmod +x /mnt/fast/apps/homelab/tooling/data/backups/backup-truenas.sh

# Fix backup directory permissions
sudo chown -R root:root /mnt/tank/backups/
sudo chmod -R 755 /mnt/tank/backups/
```

## Advanced

### Manual Backup of Specific Services

The script supports selective backup of one or more services:

```bash
# Backup only Prowlarr
sudo /mnt/fast/apps/homelab/tooling/data/backups/backup-services.sh prowlarr

# Backup multiple specific services
sudo /mnt/fast/apps/homelab/tooling/data/backups/backup-services.sh immich vaultwarden homeassistant

# Backup all *arr services
sudo /mnt/fast/apps/homelab/tooling/data/backups/backup-services.sh prowlarr sonarr radarr readarr

# List available services
sudo /mnt/fast/apps/homelab/tooling/data/backups/backup-services.sh --list

# Show help with examples
sudo /mnt/fast/apps/homelab/tooling/data/backups/backup-services.sh --help
```

Available services: `immich`, `vaultwarden`, `otterwiki`, `homeassistant`, `jellyfin`, `tailscale`, `traefik`, `prowlarr`, `sonarr`, `radarr`, `readarr`

**Note**: If no services are specified, all services will be backed up (default behavior for cron jobs).

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
| **Services backup script** | `/mnt/fast/apps/homelab/tooling/data/backups/backup-services.sh` |
| **TrueNAS backup script** | `/mnt/fast/apps/homelab/tooling/data/backups/backup-truenas.sh` |
| **Status check script** | `/mnt/fast/apps/homelab/tooling/data/backups/backup-check.sh` |
| **Services backup log** | `/mnt/fast/apps/homelab/tooling/data/backups/backup-services.log` |
| **TrueNAS backup log** | `/mnt/fast/apps/homelab/tooling/data/backups/backup-truenas.log` |
| **Service backups** | `/mnt/tank/backups/homelab/` |
| **TrueNAS config backups** | `/mnt/tank/backups/truenas/` |
| **Service restore guides** | `/mnt/fast/apps/homelab/tooling/data/backups/services/` |

## Storage Estimates

At full retention capacity:

- **Homelab services**: ~50GB (23 backups × ~2.0GB per run)
- **TrueNAS config**: ~10MB (14 folders × ~700KB per folder)
- **Total**: ~50GB

**Offsite (B2) with weekly + monthly only:**
- **Homelab services**: ~20GB (10 backups)
- **TrueNAS config**: ~5MB (7 folders)
- **Estimated cost**: ~$0.27/month or $3.24/year

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
