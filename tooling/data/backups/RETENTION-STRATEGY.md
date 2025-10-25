# Backup Retention Strategy

## Tiered Retention (Grandfather-Father-Son)

This backup system uses a **tiered retention strategy** that balances recovery flexibility with storage efficiency.

## Retention Tiers

```
┌─────────────┬──────────────┬────────────┬──────────────┐
│ Tier        │ Frequency    │ Retention  │ Recovery     │
│             │              │            │ Points       │
├─────────────┼──────────────┼────────────┼──────────────┤
│ Twice-daily │ 7 AM & 7 PM  │ 3 days     │ 6 points     │
│ Daily       │ Midnight     │ 7 days     │ 7 points     │
│ Weekly      │ Sun midnight │ 4 weeks    │ 4 points     │
│ Monthly     │ 1st midnight │ 6 months   │ 6 points     │
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
Yesterday┊         │       │        │
7 PM     ┊   ✓     │       │        │
-2d 7AM  ┊   ✓     │       │        │
-2d 7PM  ┊   ✓     │       │        │
-3d 7AM  ┊   ✓     │       │        │
-3d 7PM  ┊   ✓     │       │        │
-4d 00:00┊         │   ✓   │        │
-5d 00:00┊         │   ✓   │        │
...      ┊         │  ...  │        │
-7d 00:00┊         │   ✓   │        │
-14d     ┊         │       │   ✓    │
-21d     ┊         │       │   ✓    │
-28d     ┊         │       │   ✓    │
-1mo     ┊         │       │        │   ✓
-2mo     ┊         │       │        │   ✓
...      ┊         │       │        │  ...
-6mo     ┊         │       │        │   ✓
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

For cloud backup to Backblaze B2, **only backup weekly and monthly**:

```
Weekly:   4 backups × 2.0 GB =  8 GB
Monthly:  6 backups × 2.0 GB = 12 GB
──────────────────────────────────────
Total:   10 backups           = 20 GB

Estimated B2 cost: ~$0.27/month or $3.24/year
```

**TrueNAS Cloud Sync exclude patterns:**
```
*twice-daily*
*-daily-*
```

This keeps costs minimal while maintaining 4 weeks + 6 months of offsite backups.

## Recovery Scenarios

### Scenario 1: "I need to restore from this morning"
✅ **Twice-daily backup available**
- Recovery Point: 7 AM today
- File: `db-twice-daily-YYYYMMDD-0700.sql.gz`

### Scenario 2: "I need to restore from 3 days ago"
✅ **Daily backup available**
- Recovery Point: Midnight 3 days ago
- File: `db-daily-YYYYMMDD-0000.sql.gz`

### Scenario 3: "I need to restore from 2 weeks ago"
✅ **Weekly backup available**
- Recovery Point: Sunday midnight 2 weeks ago
- File: `db-weekly-YYYYMMDD-0000.sql.gz`

### Scenario 4: "I need to restore from 4 months ago"
✅ **Monthly backup available**
- Recovery Point: 1st of month 4 months ago
- File: `db-monthly-YYYYMMDD-0000.sql.gz`

### Scenario 5: "I need to restore from exactly 2 days ago at 3 PM"
⚠️ **Not available** - Nearest recovery points:
- 2 days ago 7 PM (twice-daily) or
- 3 days ago midnight (daily)

## Backup Type Selection Logic

The script automatically determines backup type based on current time:

```bash
if [ month_day == 1 ] && [ hour == 0 ]; then
  → Create MONTHLY backup
elif [ weekday == Sunday ] && [ hour == 0 ]; then
  → Create WEEKLY backup
elif [ hour == 0 ]; then
  → Create DAILY backup
else
  → Create TWICE-DAILY backup (runs at 7 AM and 7 PM)
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

✅ **Recent flexibility**: Twice-daily backups for last 3 days (7 AM and 7 PM)  
✅ **Medium-term coverage**: Daily backups for last week  
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

Check retention status:

```bash
# Run the status check script
/mnt/fast/apps/homelab/tooling/data/backups/backup-check.sh

# Or manually count by type
echo "Twice-daily: $(find /mnt/tank/backups/homelab -name '*twice-daily*' | wc -l)"
echo "Daily:       $(find /mnt/tank/backups/homelab -name '*daily*' | wc -l)"
echo "Weekly:      $(find /mnt/tank/backups/homelab -name '*weekly*' | wc -l)"
echo "Monthly:     $(find /mnt/tank/backups/homelab -name '*monthly*' | wc -l)"
```

## Customization

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

## Related Documentation

- Main README: [README.md](README.md)
- Main backup script: [backup-services.sh](backup-services.sh)
- Status checker: [backup-check.sh](backup-check.sh)
- TrueNAS setup: [TRUENAS-CRON-SETUP.md](TRUENAS-CRON-SETUP.md)
- Service restore guides: [services/](services/)
