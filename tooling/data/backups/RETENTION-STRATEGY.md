# Backup Retention Strategy

## Two Backup Systems

This infrastructure includes **two separate backup systems**:

1. **Homelab Services**: Docker container backups (databases, configs, data)
2. **TrueNAS Configuration**: System-level OS configuration for disaster recovery

Both use tiered retention strategies optimized for their purpose.

---

## Homelab Services Retention

### Tiered Retention (Grandfather-Father-Son)

This backup system uses a **tiered retention strategy** that balances recovery flexibility with storage efficiency.

## Retention Tiers

```
┌─────────────┬──────────────┬────────────┬──────────────┐
│ Tier        │ Frequency    │ Retention  │ Recovery     │
│             │              │            │ Points       │
├─────────────┼──────────────┼────────────┼──────────────┤
│ Twice-daily │ 7 AM         │ 3 days     │ 6 points     │
│ Daily       │ 7 PM         │ 7 days     │ 7 points     │
│ Weekly      │ Sun 7 PM     │ 4 weeks    │ 4 points     │
│ Monthly     │ 1st 7 PM     │ 6 months   │ 6 points     │
└─────────────┴──────────────┴────────────┴──────────────┘

Total Recovery Points: ~23 per service
Total Storage: ~50GB at full retention (all 7 services)
```

## Timeline Visualization

```
Time     ┊ 2×daily │ Daily │ Weekly │ Monthly
─────────┼─────────┼───────┼────────┼─────────
Now      ┊         │       │        │
7 AM     ┊   ✓     │       │        │
-1d 7PM  ┊         │   ✓   │        │
-2d 7PM  ┊         │   ✓   │        │
-3d 7AM  ┊   ✓     │       │        │
-3d 7PM  ┊         │   ✓   │        │
-4d 7PM  ┊         │   ✓   │        │
-5d 7PM  ┊         │   ✓   │        │
...      ┊         │  ...  │        │
-7d 7PM  ┊         │   ✓   │        │
-14d 7PM ┊         │       │   ✓    │
-21d 7PM ┊         │       │   ✓    │
-28d 7PM ┊         │       │   ✓    │
-1mo 7PM ┊         │       │        │   ✓
-2mo 7PM ┊         │       │        │   ✓
...      ┊         │       │        │  ...
-6mo 7PM ┊         │       │        │   ✓
```

## Storage Estimate

### Current Backup Sizes (per run):
```
Immich:         323 MB  (251M db + 72M storage)
Vaultwarden:    322 KB  (~876K db + 1.7K key + 9.4K attachments)
OtterWiki:       12 KB
Home Assistant:  73 MB  (2 databases + configs)
Jellyfin:       1.6 GB  (full backup with metadata)
Tailscale:        1 KB
Traefik:          1 KB
──────────────────────
Total per run:  ~2.0 GB
```

### Full Retention Storage:
```
Twice-daily: 6 backups  × 2.0 GB = 12 GB
Daily:       7 backups  × 2.0 GB = 14 GB
Weekly:      4 backups  × 2.0 GB =  8 GB
Monthly:     6 backups  × 2.0 GB = 12 GB
────────────────────────────────────────
Total:      23 backups           = 46 GB

With headroom for growth: ~50 GB
```

## Offsite Backup (B2) Strategy

For cloud backup to Backblaze B2, **exclude daily backups** to reduce costs:

### Services (homelab directory)
```
Weekly:   4 backups × 2.0 GB =  8 GB
Monthly:  6 backups × 2.0 GB = 12 GB
──────────────────────────────────────
Total:   10 backups           = 20 GB
```

### TrueNAS Config (truenas directory)
```
Weekly:   4 folders × 700 KB = 2.8 MB
Monthly:  3 folders × 700 KB = 2.1 MB
──────────────────────────────────────
Total:    7 folders           = 4.9 MB
```

**Combined B2 Storage: ~20 GB**

**TrueNAS Cloud Sync exclude pattern:**
```
daily-*
```

This single pattern excludes:
- Service backups: `*-daily-*` files
- Service backups: `*-twice-daily-*` files  
- TrueNAS backups: `daily-YYYYMMDD-HHMM/` folders

**Estimated B2 cost: ~$0.27/month or $3.24/year**

This keeps costs minimal while maintaining 4 weeks + 6 months of offsite backups for both systems.

## Recovery Scenarios

### Scenario 1: "I need to restore from this morning"
✅ **Twice-daily backup available**
- Recovery Point: 7 AM today
- File: `db-twice-daily-YYYYMMDD-0700.sql.gz`

### Scenario 2: "I need to restore from yesterday evening"
✅ **Daily backup available**
- Recovery Point: 7 PM yesterday
- File: `db-daily-YYYYMMDD-1900.sql.gz`

### Scenario 3: "I need to restore from 2 weeks ago"
✅ **Weekly backup available**
- Recovery Point: Sunday 7 PM, 2 weeks ago
- File: `db-weekly-YYYYMMDD-1900.sql.gz`

### Scenario 4: "I need to restore from 4 months ago"
✅ **Monthly backup available**
- Recovery Point: 1st of month, 7 PM, 4 months ago
- File: `db-monthly-YYYYMMDD-1900.sql.gz`

### Scenario 5: "I need to restore from exactly 2 days ago at 3 PM"
⚠️ **Not available** - Nearest recovery points:
- 2 days ago 7 PM (daily) or
- Today 7 AM (twice-daily)

## Backup Type Selection Logic

The script automatically determines backup type based on current time:

```bash
if [ month_day == 1 ] && [ hour == 19 ]; then
  → Create MONTHLY backup
elif [ weekday == Sunday ] && [ hour == 19 ]; then
  → Create WEEKLY backup
elif [ hour == 19 ]; then
  → Create DAILY backup
else
  → Create TWICE-DAILY backup (runs at 7 AM)
fi
```

## Cleanup Logic

Automatic cleanup runs after each backup:

```bash
# Core backups (databases, configs, storage)
Twice-daily: Delete if > 3 days old
Daily:       Delete if > 7 days old
Weekly:      Delete if > 28 days old
Monthly:     Delete if > 180 days old

# Vaultwarden RSA keys and attachments
Only deleted if corresponding database backup no longer exists (orphan cleanup)
```

This ensures:
- Complete backup sets are kept together
- RSA keys never deleted while database exists
- All 3 Vaultwarden files (db + key + attachments) remain synchronized

## Benefits

✅ **Recent flexibility**: Twice-daily backups (7 AM) for last 3 days  
✅ **Daily coverage**: Daily backups (7 PM) for last week  
✅ **Long-term compliance**: Monthly backups for 6 months  
✅ **Storage efficient**: ~50GB total vs hundreds of GB with hourly backups
✅ **Automated**: No manual intervention needed  
✅ **Homelab appropriate**: Twice daily is perfect for non-production environments
✅ **Cloud-ready**: Weekly/monthly subset perfect for offsite backup at minimal cost

## Services Covered

All 7 homelab services backed up:
1. **Immich**: PostgreSQL database + storage files (library, upload, profile)
2. **Vaultwarden**: SQLite database + RSA keys + attachments
3. **OtterWiki**: SQLite database
4. **Home Assistant**: Main SQLite + Zigbee SQLite + YAML configs
5. **Jellyfin**: Full backup (databases + metadata + plugins)
6. **Tailscale**: State files
7. **Traefik**: ACME SSL certificates

## Monitoring

Check retention status for both systems:

```bash
# Full status report (both systems)
/mnt/fast/apps/homelab/tooling/data/backups/backup-check.sh

# Or manually count by type (services only)
echo "Twice-daily: $(find /mnt/tank/backups/homelab -name '*twice-daily*' | wc -l)"
echo "Daily:       $(find /mnt/tank/backups/homelab -name '*daily*' | wc -l)"
echo "Weekly:      $(find /mnt/tank/backups/homelab -name '*weekly*' | wc -l)"
echo "Monthly:     $(find /mnt/tank/backups/homelab -name '*monthly*' | wc -l)"

# TrueNAS config backups
echo "Daily:       $(find /mnt/tank/backups/truenas -type d -name 'daily-*' | wc -l)"
echo "Weekly:      $(find /mnt/tank/backups/truenas -type d -name 'weekly-*' | wc -l)"
echo "Monthly:     $(find /mnt/tank/backups/truenas -type d -name 'monthly-*' | wc -l)"
```

## Customization

### Services Retention

To adjust retention periods, edit `backup-services.sh`:

```bash
# In the cleanup section around line 420, change these values:

# Twice-daily retention (currently 3 days)
-mtime +3 -delete

# Daily retention (currently 7 days)
-mtime +7 -delete

# Weekly retention (currently 28 days / 4 weeks)
-mtime +28 -delete

# Monthly retention (currently 180 days / 6 months)
-mtime +180 -delete
```

### TrueNAS Config Retention

To adjust TrueNAS backup retention, edit `backup-truenas.sh`:

```bash
# In the cleanup section around line 110, change these values:

# Daily retention (currently 7 days)
-mtime +7 -type d -print0

# Weekly retention (currently 28 days / 4 weeks)
-mtime +28 -type d -print0

# Monthly retention (currently 90 days / 3 months)
-mtime +90 -type d -print0
```

---

## TrueNAS Configuration Retention

### Backup Frequency

```
┌──────────┬──────────┬────────────┬──────────────┐
│ Tier     │ Schedule │ Retention  │ Folders      │
├──────────┼──────────┼────────────┼──────────────┤
│ Daily    │ 1 AM     │ 7 days     │ 7 folders    │
│ Weekly   │ Sun 1 AM │ 28 days    │ 4 folders    │
│ Monthly  │ 1st 1 AM │ 90 days    │ 3 folders    │
└──────────┴──────────┴────────────┴──────────────┘

Total Recovery Points: ~14 folders
Total Storage: ~10 MB
```

### Storage Estimate

```
Each backup folder: ~700 KB (6 files)
  - truenas-config.tar.gz  (~500 KB)
  - ssh-keys.tar.gz        (~50 KB)
  - ssl-certs.tar.gz       (~100 KB)
  - zfs-config.txt         (~20 KB)
  - network.txt            (~10 KB)
  - cronjobs.json          (~5 KB)

Full retention: 14 folders × 700 KB = ~10 MB
```

### Cleanup Logic

```bash
# Delete entire folders (not individual files)
Daily:   Delete folders > 7 days old
Weekly:  Delete folders > 28 days old
Monthly: Delete folders > 90 days old
```

### Why Shorter Retention?

TrueNAS configs change infrequently compared to service data:
- **90 days monthly** is sufficient for config rollback
- Minimal storage impact (~10 MB total)
- More focused on disaster recovery than point-in-time restore

---

## Related Documentation

- Main README: [README.md](README.md)
- Services backup script: [backup-services.sh](backup-services.sh)
- TrueNAS backup script: [backup-truenas.sh](backup-truenas.sh)
- Status checker: [backup-check.sh](backup-check.sh)
- TrueNAS setup: [TRUENAS-CRON-SETUP.md](TRUENAS-CRON-SETUP.md)
- Service restore guides: [services/](services/)
