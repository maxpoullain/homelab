# Vaultwarden Restore Guide

This guide explains how to restore Vaultwarden from backups located in `/mnt/tank/backups/homelab/vaultwarden/`.

## Backup Files

- `db-[type]-[date].sqlite3` - Main database (accounts, passwords, items)
- `rsa_key-[type]-[date].pem` - RSA private key (for encryption)
- `attachments-[type]-[date].tar.gz` - File attachments

**Important**: All three files from the same backup run are required for a complete restore.

## Quick Restore

### 1. Stop Vaultwarden

```bash
cd /mnt/fast/apps/homelab/vault
docker compose down
```

### 2. Restore All Files

```bash
# Choose your backup timestamp (e.g., daily-20251025-2236)
BACKUP_DATE="daily-20251025-2236"
BACKUP_DIR="/mnt/tank/backups/homelab/vaultwarden"

# Get the Vaultwarden data directory
DATA_DIR="/mnt/fast/apps/homelab/vault/vw-data"

# Restore database
cp "$BACKUP_DIR/db-$BACKUP_DATE.sqlite3" "$DATA_DIR/db.sqlite3"

# Restore RSA key
cp "$BACKUP_DIR/rsa_key-$BACKUP_DATE.pem" "$DATA_DIR/rsa_key.pem"

# Restore attachments (if exists)
if [ -f "$BACKUP_DIR/attachments-$BACKUP_DATE.tar.gz" ]; then
  tar -xzf "$BACKUP_DIR/attachments-$BACKUP_DATE.tar.gz" -C "$DATA_DIR/"
fi

# Fix permissions
sudo chown -R 1000:1000 "$DATA_DIR"
```

### 3. Start Vaultwarden

```bash
cd /mnt/fast/apps/homelab/vault
docker compose up -d
```

### 4. Verify Restore

```bash
# Check logs
docker logs vaultwarden

# Test login via web UI
# Navigate to https://vault.yourdomain.com
```

## Partial Restore

### Database Only (Dangerous!)

⚠️ **Warning**: Restoring only the database without the matching RSA key will make your vault **unusable**. The RSA key is required to decrypt vault data.

Only do this if you're certain the RSA key hasn't changed:

```bash
cp /mnt/tank/backups/homelab/vaultwarden/db-daily-20251025-2236.sqlite3 \
   /mnt/fast/apps/homelab/vault/vw-data/db.sqlite3
```

### Attachments Only

If you only need to restore file attachments:

```bash
tar -xzf /mnt/tank/backups/homelab/vaultwarden/attachments-daily-20251025-2236.tar.gz \
  -C /mnt/fast/apps/homelab/vault/vw-data/
sudo chown -R 1000:1000 /mnt/fast/apps/homelab/vault/vw-data/attachments/
```

## Verify Backup Integrity

Before restoring, verify the backup set is complete:

```bash
BACKUP_DATE="daily-20251025-2236"
BACKUP_DIR="/mnt/tank/backups/homelab/vaultwarden"

# Check all three files exist
ls -lh "$BACKUP_DIR/db-$BACKUP_DATE.sqlite3"
ls -lh "$BACKUP_DIR/rsa_key-$BACKUP_DATE.pem"
ls -lh "$BACKUP_DIR/attachments-$BACKUP_DATE.tar.gz"

# Verify SQLite database
sqlite3 "$BACKUP_DIR/db-$BACKUP_DATE.sqlite3" "PRAGMA integrity_check;"
```

## Disaster Recovery

If you need to restore to a **new server**:

1. Install Docker and Docker Compose
2. Copy the entire compose.yml from `/mnt/fast/apps/homelab/vault/`
3. Follow the restore steps above before first starting Vaultwarden
4. Update DNS/reverse proxy to point to new server
5. Verify SSL certificates are valid

## Troubleshooting

### "Failed to decrypt" errors after restore

This means the RSA key doesn't match the database:

- **Solution**: Restore both database AND RSA key from the SAME backup timestamp
- The RSA key must match the one used when data was encrypted

### Missing attachments

Check if attachments existed in the backup:

```bash
tar -tzf /mnt/tank/backups/homelab/vaultwarden/attachments-daily-20251025-2236.tar.gz
```

If the archive is empty or very small, you may not have had attachments.

### Permission errors

```bash
sudo chown -R 1000:1000 /mnt/fast/apps/homelab/vault/vw-data/
sudo chmod 600 /mnt/fast/apps/homelab/vault/vw-data/rsa_key.pem
sudo chmod 644 /mnt/fast/apps/homelab/vault/vw-data/db.sqlite3
```

## Important Notes

- **RSA Key is Critical**: Without the correct RSA key, the vault data is **permanently unrecoverable**
- **Backup Set Integrity**: Always restore database, RSA key, and attachments from the **same backup run**
- **Test Restores**: Periodically test your backups on a separate system to verify they work
- **Backup Method**: Uses Vaultwarden's built-in `/vaultwarden backup` command for database consistency
