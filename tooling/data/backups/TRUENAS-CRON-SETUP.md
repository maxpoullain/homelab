# TrueNAS Cron Job Setup Guide

Complete guide for setting up automated backups using TrueNAS Cron Jobs.

## Two Backup Systems

This guide covers setup for **two separate backup scripts**:

1. **Homelab Services** (`backup-services.sh`) - Docker container backups
2. **TrueNAS Configuration** (`backup-truenas.sh`) - System OS config backups

Both are scheduled via TrueNAS cron jobs for centralized management.

---

## Homelab Services Backup

## Why Use TrueNAS Cron Jobs?

✅ **Integrated monitoring** - View job status in TrueNAS UI  
✅ **Email notifications** - Get alerts on failures (if SMTP configured)  
✅ **Centralized management** - All scheduled tasks in one place  
✅ **Persistent across updates** - Survives TrueNAS upgrades  
✅ **Better logging** - TrueNAS tracks execution history  

## Setup via TrueNAS Web Interface

### Services Backup Job

### Step 1: Navigate to Cron Jobs

1. Log into TrueNAS web interface
2. Click **Tasks** in left sidebar
3. Click **Cron Jobs**
4. Click **Add** button (top right)

### Step 2: Configure the Cron Job

Fill in the following fields:

#### Basic Settings

| Field | Value | Notes |
|-------|-------|-------|
| **Description** | `Homelab Service Backups (Twice Daily)` | Descriptive name |
| **Command** | `/mnt/fast/apps/homelab/tooling/data/backups/backup-services.sh` | Full path to script |
| **Run As User** | `root` | Required for Docker access |

#### Schedule Settings

| Field | Value | Notes |
|-------|-------|-------|
| **Schedule Preset** | `Custom` | For specific times |
| **Minutes** | `0` | Run at the top of the hour |
| **Hours** | `7,19` | 7 AM and 7 PM |
| **Days of Month** | `*` | Every day |
| **Months** | `*` | Every month |
| **Days of Week** | `*` | All days |

#### Output Settings

| Field | Value | Notes |
|-------|-------|-------|
| **Hide Standard Output** | `☐ Unchecked` | See success messages |
| **Hide Standard Error** | `☐ Unchecked` | See error messages |
| **Enabled** | `☑ Checked` | Activate the job |

### Step 3: Save and Verify

1. Click **Save**
2. Verify the cron job appears in the list
3. Check the schedule shows: `0 7,19 * * *`

---

## TrueNAS Configuration Backup

### Step 1: Add Second Cron Job

1. Still in **Tasks → Cron Jobs**
2. Click **Add** button again

### Step 2: Configure TrueNAS Backup Job

Fill in the following fields:

#### Basic Settings

| Field | Value | Notes |
|-------|-------|-------|
| **Description** | `TrueNAS Configuration Backup (Daily)` | Descriptive name |
| **Command** | `/mnt/fast/apps/homelab/tooling/data/backups/backup-truenas.sh` | Full path to script |
| **Run As User** | `root` | Required for system access |

#### Schedule Settings

| Field | Value | Notes |
|-------|-------|-------|
| **Schedule Preset** | `Custom` | For specific time |
| **Minutes** | `0` | Run at the top of the hour |
| **Hours** | `1` | 1 AM (after service backups) |
| **Days of Month** | `*` | Every day |
| **Months** | `*` | Every month |
| **Days of Week** | `*` | All days |

#### Output Settings

| Field | Value | Notes |
|-------|-------|-------|
| **Hide Standard Output** | `☐ Unchecked` | See success messages |
| **Hide Standard Error** | `☐ Unchecked` | See error messages |
| **Enabled** | `☑ Checked` | Activate the job |

### Step 3: Save and Verify

1. Click **Save**
2. Verify both cron jobs appear in the list:
   - Services backup at `0 7,19 * * *`
   - TrueNAS config at `0 1 * * *`

### What Gets Backed Up

Each TrueNAS backup creates a **folder** containing 6 files:

```
/mnt/tank/backups/truenas/
├── daily-20251026-0100/
│   ├── truenas-config.tar.gz  (system settings, users, shares)
│   ├── ssh-keys.tar.gz        (SSH host keys)
│   ├── ssl-certs.tar.gz       (web UI certificates)
│   ├── zfs-config.txt         (pool configuration)
│   ├── network.txt            (network settings)
│   └── cronjobs.json          (scheduled tasks)
```

**Size**: ~700 KB per backup folder  
**Purpose**: Disaster recovery (restore after OS reinstall)

### Schedule Explanation: `0 1 * * *`

```
┌───────────── Minute (0)
│ ┌─────────── Hour (1) = 1 AM
│ │ ┌───────── Day of Month (*) = Every day
│ │ │ ┌─────── Month (*) = Every month
│ │ │ │ ┌───── Day of Week (*) = All days
│ │ │ │ │
0 1 * * *
```

**Runs at 1 AM daily** - Script determines backup type:
- **Daily**: Monday-Saturday at 1 AM (7 days retention)
- **Weekly**: Sunday at 1 AM (28 days retention)
- **Monthly**: 1st of month at 1 AM (90 days retention)

**Why 1 AM?** Runs before service backups (7 AM/7 PM) and captures system state separately.

---

## Combined Backup Schedule

## Visual Guide

### TrueNAS Cron Job Form

```
┌─────────────────────────────────────────────────────────┐
│ Add Cron Job                                            │
├─────────────────────────────────────────────────────────┤
│ Description:                                             │
│ ┌─────────────────────────────────────────────────────┐ │
│ │ Homelab Service Backups (Twice Daily)               │ │
│ └─────────────────────────────────────────────────────┘ │
│                                                          │
│ Command: *                                               │
│ ┌─────────────────────────────────────────────────────┐ │
│ │ /mnt/fast/apps/homelab/tooling/data/backups/       │ │
│ │ backup-services.sh                                   │ │
│ └─────────────────────────────────────────────────────┘ │
│                                                          │
│ Run As User: *                                           │
│ ┌───────────┐                                           │
│ │ root    ▼ │                                           │
│ └───────────┘                                           │
│                                                          │
│ Schedule:                                                │
│ ┌──────────────┐                                        │
│ │ Custom     ▼ │                                        │
│ └──────────────┘                                        │
│                                                          │
│ Minutes: ┌────┐  Hours: ┌────────┐  Days: ┌───┐       │
│          │ 0  │          │ 7,19   │        │ * │       │
│          └────┘          └────────┘        └───┘       │
│                                                          │
│ Months: ┌───┐  Days of Week: ┌───┐                     │
│         │ * │                 │ * │                     │
│         └───┘                 └───┘                     │
│                                                          │
│ ☐ Hide Standard Output                                  │
│ ☐ Hide Standard Error                                   │
│ ☑ Enabled                                                │
│                                                          │
│          [Cancel]                    [Save]             │
└─────────────────────────────────────────────────────────┘
```

## Schedule Explanation

### Cron Syntax: `0 7,19 * * *`

```
┌───────────── Minute (0)
│ ┌─────────── Hour (7,19) = 7 AM and 7 PM
│ │ ┌───────── Day of Month (*) = Every day
│ │ │ ┌─────── Month (*) = Every month
│ │ │ │ ┌───── Day of Week (*) = All days
│ │ │ │ │
0 7,19 * * *
```

### When Backups Run

| Time | Day | Services Backup | TrueNAS Config |
|------|-----|-----------------|----------------|
| 01:00 | Mon-Sat | - | daily |
| 01:00 | Sunday | - | **weekly** |
| 01:00 | 1st of month | - | **monthly** |
| 07:00 | All days | twice-daily | - |
| 19:00 | Mon-Sat | **daily** | - |
| 19:00 | Sunday | **weekly** | - |
| 19:00 | 1st of month | **monthly** | - |

**Key Points**:
- TrueNAS config backups run at **1 AM** (before services wake up)
- Services twice-daily backups run at **7 AM**
- Services daily/weekly/monthly backups run at **7 PM**
- No conflicts - different times

## All Services and Systems Covered

### Homelab Services (7 total):

1. **Immich** - PostgreSQL database + storage files
2. **Vaultwarden** - SQLite database + RSA keys + attachments
3. **OtterWiki** - SQLite database
4. **Home Assistant** - Main + Zigbee databases + YAML configs
5. **Jellyfin** - Full backup (databases + metadata + plugins)
6. **Tailscale** - State files
7. **Traefik** - ACME SSL certificates

### TrueNAS System (1 job, 6 components):

1. System configuration (settings, users, shares)
2. SSH host keys
3. SSL certificates
4. ZFS pool configuration
5. Network settings
6. Cron jobs

## Verification

### Via TrueNAS UI

1. **Tasks → Cron Jobs**
2. Look for **both jobs** in the list:
   - Homelab Service Backups (Twice Daily)
   - TrueNAS Configuration Backup (Daily)
3. Both should show **Enabled** ✓

### Via SSH

```bash
# View root's crontab
sudo crontab -l

# You should see both jobs:
# 0 7,19 * * * /mnt/fast/apps/homelab/tooling/data/backups/backup-services.sh
# 0 1 * * * /mnt/fast/apps/homelab/tooling/data/backups/backup-truenas.sh
```

### Test Manual Run

```bash
# Test services backup
sudo /mnt/fast/apps/homelab/tooling/data/backups/backup-services.sh

# Test TrueNAS backup
sudo /mnt/fast/apps/homelab/tooling/data/backups/backup-truenas.sh

# Check both logs
tail -50 /mnt/fast/apps/homelab/tooling/data/backups/backup-services.log
tail -50 /mnt/fast/apps/homelab/tooling/data/backups/backup-truenas.log

# Verify backups were created
ls -lth /mnt/tank/backups/homelab/*/
ls -lth /mnt/tank/backups/truenas/
```

## Monitoring

### View Cron Job Logs

TrueNAS logs cron job execution. To view:

```bash
# System logs showing cron execution
cat /var/log/cron

# Or filter for your specific jobs
grep "backup-services\|backup-truenas" /var/log/cron

# View each script's own log
tail -f /mnt/fast/apps/homelab/tooling/data/backups/backup-services.log
tail -f /mnt/fast/apps/homelab/tooling/data/backups/backup-truenas.log
```

### Check Status with backup-check.sh

```bash
# Run the comprehensive status check (both systems)
sudo /mnt/fast/apps/homelab/tooling/data/backups/backup-check.sh
```

This shows:
- Cron job configuration (both scripts)
- Container status for all 7 services
- Last backup time per service
- Service backup file counts
- Vaultwarden backup set validation
- Home Assistant database pairs
- **TrueNAS config backup status**
- **TrueNAS folder counts and validation**
- Total disk usage for both systems

### Check Last Run

In TrueNAS UI:
1. **Tasks → Cron Jobs**
2. Find your job
3. Look at **Last Run** column

### Email Notifications (Optional)

If you have SMTP configured in TrueNAS:

1. **System → Email** - Configure SMTP settings
2. **System → Alert Settings**
3. Enable: **Cron Job Failed** alerts

You'll get emails if the backup script exits with an error code.

## Troubleshooting

### Cron jobs not running

```bash
# Check if cron service is running
sudo service cron status

# Check TrueNAS middleware logs
sudo tail -f /var/log/middlewared.log | grep cron

# Check if both scripts are executable
ls -l /mnt/fast/apps/homelab/tooling/data/backups/backup-*.sh
# Should show: -rwxr-xr-x (executable)

# Make executable if needed
sudo chmod +x /mnt/fast/apps/homelab/tooling/data/backups/backup-services.sh
sudo chmod +x /mnt/fast/apps/homelab/tooling/data/backups/backup-truenas.sh
```

### Services backup runs but fails

```bash
# Check the services log
tail -100 /mnt/fast/apps/homelab/tooling/data/backups/backup-services.log

# Run manually to see errors
sudo /mnt/fast/apps/homelab/tooling/data/backups/backup-services.sh

# Check Docker containers are running
docker ps | grep -E "immich_postgres|vaultwarden|otterwiki|^ha$|jellyfin|tailscale|traefik"
```

### TrueNAS backup runs but fails

```bash
# Check the TrueNAS log
tail -100 /mnt/fast/apps/homelab/tooling/data/backups/backup-truenas.log

# Run manually to see errors
sudo /mnt/fast/apps/homelab/tooling/data/backups/backup-truenas.sh

# Check TrueNAS system files exist
ls -l /data/freenas-v1.db
ls -l /usr/local/etc/ssh/
ls -l /etc/certificates/
```

### No backups created

```bash
# Check both backup directories exist and are writable
ls -la /mnt/tank/backups/homelab/
ls -la /mnt/tank/backups/truenas/

# Check disk space
df -h /mnt/tank

# Check script permissions
sudo -u root /mnt/fast/apps/homelab/tooling/data/backups/backup-services.sh
sudo -u root /mnt/fast/apps/homelab/tooling/data/backups/backup-truenas.sh
```

### Incomplete TrueNAS backups

```bash
# Check if backup folders have all 6 files
find /mnt/tank/backups/truenas/ -type d -name "*-*" -exec sh -c 'echo -n "$1: "; ls "$1" | wc -l' _ {} \;

# Each should show: 6 (if less, backup incomplete)

# Expected files in each folder:
# - truenas-config.tar.gz
# - ssh-keys.tar.gz
# - ssl-certs.tar.gz
# - zfs-config.txt
# - network.txt
# - cronjobs.json
```

```bash
### Incomplete Vaultwarden backups

```bash
# Check if all 3 files exist for each backup
ls -lh /mnt/tank/backups/homelab/vaultwarden/

# Should see matching timestamps:
# db-TYPE-TIMESTAMP.sqlite3
# rsa_key-TYPE-TIMESTAMP.pem
# attachments-TYPE-TIMESTAMP.tar.gz

# If orphaned files exist, the cleanup will remove them on next run
```

## Alternative: CLI Setup

If you prefer using the command line:

```bash
# Add services backup cron job
midclt call cronjob.create '{
  "user": "root",
  "command": "/mnt/fast/apps/homelab/tooling/data/backups/backup-services.sh",
  "description": "Homelab Service Backups (Twice Daily)",
  "schedule": {
    "minute": "0",
    "hour": "7,19",
    "dom": "*",
    "month": "*",
    "dow": "*"
  },
  "stdout": true,
  "stderr": true,
  "enabled": true
}'

# Add TrueNAS config backup cron job
midclt call cronjob.create '{
  "user": "root",
  "command": "/mnt/fast/apps/homelab/tooling/data/backups/backup-truenas.sh",
  "description": "TrueNAS Configuration Backup (Daily)",
  "schedule": {
    "minute": "0",
    "hour": "1",
    "dom": "*",
    "month": "*",
    "dow": "*"
  },
  "stdout": true,
  "stderr": true,
  "enabled": true
}'

# List all cron jobs
midclt call cronjob.query

# Delete a cron job (replace ID)
midclt call cronjob.delete <job_id>
```
```

## Alternative: CLI Setup

If you prefer using the command line:

```bash
# Add cron job via TrueNAS CLI
midclt call cronjob.create '{
  "user": "root",
  "command": "/mnt/fast/apps/homelab/tooling/data/backups/backup-services.sh",
  "description": "Homelab Service Backups (Twice Daily)",
  "schedule": {
    "minute": "0",
    "hour": "7,19",
    "dom": "*",
    "month": "*",
    "dow": "*"
  },
  "stdout": true,
  "stderr": true,
  "enabled": true
}'

# List all cron jobs
midclt call cronjob.query

# Delete a cron job (replace ID)
midclt call cronjob.delete <job_id>
```

## Offsite Backup to B2

### Setup Cloud Sync Task

For offsite backups to Backblaze B2 (weekly + monthly only):

1. **Tasks → Cloud Sync Tasks → Add**
2. **Description**: `Homelab Backups to B2 (Weekly/Monthly)`
3. **Direction**: Push
4. **Transfer Mode**: Sync
5. **Credential**: (Your B2 credentials)
6. **Bucket**: Your B2 bucket name
7. **Folder**: `/homelab-backups/`
8. **Directory/Files**: `/mnt/tank/backups`

### Exclude daily backups (both systems):

In **Advanced Options → Exclude**:
```
daily-*
```

This single pattern excludes:
- Service twice-daily backups: `*-twice-daily-*`
- Service daily backups: `*-daily-*`
- TrueNAS daily folders: `daily-YYYYMMDD-HHMM/`

**Uploads only weekly and monthly backups from both systems.**

### Storage & Cost

```
Services:
  Weekly:   4 × 2.0 GB =  8 GB
  Monthly:  6 × 2.0 GB = 12 GB
  
TrueNAS:
  Weekly:   4 × 700 KB = 2.8 MB
  Monthly:  3 × 700 KB = 2.1 MB

Total: ~20 GB
Estimated B2 cost: ~$0.27/month
```

### Schedule:
- **Daily at 2 AM** (after both backups complete)
- Cron: `0 2 * * *`

## Best Practices

✅ **Test first**: Run the script manually before scheduling  
✅ **Monitor regularly**: Check logs weekly to ensure backups are running  
✅ **Verify backups**: Periodically test restoration procedures  
✅ **Email alerts**: Configure SMTP for failure notifications  
✅ **Offsite backup**: Set up B2 sync for disaster recovery  
✅ **Document changes**: Note any schedule modifications in your homelab docs  

## Schedule Customization

### More Frequent Backups (Every 6 hours)

Change **Hours** to: `0,6,12,18`

Schedule: `0 0,6,12,18 * * *`
- Midnight, 6 AM, Noon, 6 PM
- Creates 4× daily backups
- Adjust retention: `RETENTION_DAYS=2` for twice-daily

### Once Daily (Midnight only)

Change **Hours** to: `0`

Schedule: `0 0 * * *`
- Midnight only
- All backups become daily/weekly/monthly
- Adjust retention: `RETENTION_DAYS=14` for daily

### Different Times

For 8 AM and 8 PM:
- Change **Hours** to: `8,20`
- Schedule: `0 8,20 * * *`

For 9 AM and 9 PM:
- Change **Hours** to: `9,21`
- Schedule: `0 9,21 * * *`

## Summary

**Two Cron Jobs Configured:**

### 1. Services Backup
- **Schedule**: `0 7,19 * * *`
- **7 AM**: Twice-daily backups
- **7 PM**: Daily/weekly/monthly backups (determined by date)
- **Services**: All 7 homelab containers
- **Retention**: 23 backups (~50 GB)

### 2. TrueNAS Config Backup
- **Schedule**: `0 1 * * *`
- **Frequency**: Daily at 1 AM
- **Plus**: Weekly on Sundays, monthly on 1st
- **Components**: 6 system config files
- **Retention**: 14 folders (~10 MB)

### Offsite (B2):
- **Pattern**: `*daily*` (excludes all daily/twice-daily backups)
- **Storage**: ~20 GB (weekly + monthly only)
- **Cost**: ~$0.27/month

This provides comprehensive protection for both your homelab services and TrueNAS system configuration.

## Related Documentation

- Main README: [README.md](README.md)
- Services backup script: [backup-services.sh](backup-services.sh)
- TrueNAS backup script: [backup-truenas.sh](backup-truenas.sh)
- Retention strategy: [RETENTION-STRATEGY.md](RETENTION-STRATEGY.md)
- Status checker: [backup-check.sh](backup-check.sh)
- Service restore guides: [services/](services/)
