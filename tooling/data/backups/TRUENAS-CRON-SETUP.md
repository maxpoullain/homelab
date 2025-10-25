# TrueNAS Cron Job Setup Guide

Complete guide for setting up automated homelab service backups using TrueNAS Cron Jobs.

## Why Use TrueNAS Cron Jobs?

✅ **Integrated monitoring** - View job status in TrueNAS UI  
✅ **Email notifications** - Get alerts on failures (if SMTP configured)  
✅ **Centralized management** - All scheduled tasks in one place  
✅ **Persistent across updates** - Survives TrueNAS upgrades  
✅ **Better logging** - TrueNAS tracks execution history  

## Setup via TrueNAS Web Interface

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

| Time | Day | Backup Type | Services Backed Up |
|------|-----|-------------|--------------------|
| 07:00 | Mon-Sat | twice-daily | All 7 services |
| 19:00 | Mon-Sat | twice-daily | All 7 services |
| 00:00 | Daily | **daily** | All 7 services |
| 00:00 | Sunday | **weekly** | All 7 services |
| 00:00 | 1st of month | **monthly** | All 7 services |

**Note**: The script logic at midnight (00:00) automatically determines whether to create daily, weekly, or monthly backups based on the date.

## Services Backed Up

The cron job backs up all 7 homelab services:

1. **Immich** - PostgreSQL database + storage files
2. **Vaultwarden** - SQLite database + RSA keys + attachments
3. **OtterWiki** - SQLite database
4. **Home Assistant** - Main + Zigbee databases + YAML configs
5. **Jellyfin** - Full backup (databases + metadata + plugins)
6. **Tailscale** - State files
7. **Traefik** - ACME SSL certificates

## Verification

### Via TrueNAS UI

1. **Tasks → Cron Jobs**
2. Look for your job in the list
3. Status should show **Enabled** ✓

### Via SSH

```bash
# View root's crontab (TrueNAS adds cron jobs here)
sudo crontab -l

# You should see:
# 0 7,19 * * * /mnt/fast/apps/homelab/tooling/data/backups/backup-services.sh
```

### Test Manual Run

```bash
# Run the script manually to test
sudo /mnt/fast/apps/homelab/tooling/data/backups/backup-services.sh

# Check the log
tail -50 /mnt/fast/apps/homelab/tooling/data/backups/backup-services.log

# Verify backups were created
ls -lth /mnt/tank/backups/homelab/*/
```

## Monitoring

### View Cron Job Logs

TrueNAS logs cron job execution. To view:

```bash
# System logs showing cron execution
cat /var/log/cron

# Or filter for your specific job
grep "backup-services" /var/log/cron

# View the backup script's own log
tail -f /mnt/fast/apps/homelab/tooling/data/backups/backup-services.log
```

### Check Status with backup-check.sh

```bash
# Run the comprehensive status check
sudo /mnt/fast/apps/homelab/tooling/data/backups/backup-check.sh
```

This shows:
- Container status for all services
- Last backup time per service
- Backup file counts
- Vaultwarden backup set validation
- Home Assistant database pairs
- Total disk usage

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

### Cron job not running

```bash
# Check if cron service is running
sudo service cron status

# Check TrueNAS middleware logs
sudo tail -f /var/log/middlewared.log | grep cron

# Check if script is executable
ls -l /mnt/fast/apps/homelab/tooling/data/backups/backup-services.sh
# Should show: -rwxr-xr-x (executable)

# Make executable if needed
sudo chmod +x /mnt/fast/apps/homelab/tooling/data/backups/backup-services.sh
```

### Script runs but fails

```bash
# Check the backup log
tail -100 /mnt/fast/apps/homelab/tooling/data/backups/backup-services.log

# Run manually to see errors
sudo /mnt/fast/apps/homelab/tooling/data/backups/backup-services.sh

# Check Docker containers are running
docker ps | grep -E "immich_postgres|vaultwarden|otterwiki|^ha$|jellyfin|tailscale|traefik"
```

### No backups created

```bash
# Check backup directory exists and is writable
ls -la /mnt/tank/backups/homelab/

# Check disk space
df -h /mnt/tank

# Check script permissions
sudo -u root /mnt/fast/apps/homelab/tooling/data/backups/backup-services.sh
```

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
8. **Directory/Files**: `/mnt/tank/backups/homelab`

### Exclude twice-daily and daily backups:

In **Advanced Options → Exclude**:
```
*twice-daily*
*-daily-*
```

This uploads only weekly and monthly backups, saving costs (~$0.27/month).

### Schedule:
- **Daily at 2 AM** (after midnight backups complete)
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

**Current Schedule**: `0 7,19 * * *`
- **Frequency**: Twice daily (7 AM and 7 PM)
- **Plus**: Daily at midnight, weekly on Sundays, monthly on 1st
- **Services**: All 7 homelab services
- **Retention**: 6 twice-daily + 7 daily + 4 weekly + 6 monthly = ~23 backups
- **Storage**: ~50 GB at full retention
- **Offsite (B2)**: Weekly + monthly only (~20GB, ~$0.27/month)

This provides excellent protection for a homelab environment without excessive storage use or hourly disruptions.

## Related Documentation

- Main README: [README.md](README.md)
- Backup script: [backup-services.sh](backup-services.sh)
- Retention strategy: [RETENTION-STRATEGY.md](RETENTION-STRATEGY.md)
- Status checker: [backup-check.sh](backup-check.sh)
- Service restore guides: [services/](services/)
