# Traefik Restore Guide

This guide explains how to restore Traefik from backups located in `/mnt/tank/backups/homelab/traefik/`.

## Backup Files

- `acme-[type]-[date].tar.gz` - Let's Encrypt SSL certificates

## What's Included

- `acme.json` - All SSL/TLS certificates and account information
- Let's Encrypt account key
- Certificate private keys
- Certificate data for all domains

## Quick Restore

### 1. Stop Traefik

```bash
cd /mnt/fast/apps/homelab/traefik
docker compose down
```

### 2. Restore Certificates

```bash
# Choose your backup file
BACKUP_FILE="/mnt/tank/backups/homelab/traefik/acme-daily-20251025-2236.tar.gz"

# Backup current acme.json (if it exists)
if [ -f "/mnt/fast/apps/homelab/traefik/traefik/acme/acme.json" ]; then
  cp /mnt/fast/apps/homelab/traefik/traefik/acme/acme.json \
     /mnt/fast/apps/homelab/traefik/traefik/acme/acme.json.backup.$(date +%Y%m%d)
fi

# Extract backup
tar -xzf "$BACKUP_FILE" -C /mnt/fast/apps/homelab/traefik/traefik/

# Fix permissions (CRITICAL for security)
sudo chmod 600 /mnt/fast/apps/homelab/traefik/traefik/acme/acme.json
sudo chown root:root /mnt/fast/apps/homelab/traefik/traefik/acme/acme.json
```

### 3. Start Traefik

```bash
cd /mnt/fast/apps/homelab/traefik
docker compose up -d
```

### 4. Verify Restore

```bash
# Check Traefik logs
docker logs traefik

# Should see: "No ACME certificate generation needed"
# (means certificates were loaded successfully)

# Test HTTPS endpoints
curl -I https://yourdomain.com
# Should return 200 OK with valid certificate

# Check certificate expiry
echo | openssl s_client -servername yourdomain.com -connect yourdomain.com:443 2>/dev/null | \
  openssl x509 -noout -dates
```

## When You Need This Restore

Common scenarios:

1. **Server rebuild**: Avoid Let's Encrypt rate limits by restoring certificates
2. **Accidental deletion**: Restore deleted acme.json file
3. **Corruption**: Fix corrupted certificate file
4. **Quick recovery**: Faster than re-issuing certificates (especially with many domains)

## Alternative: Let Certificates Re-issue

⚠️ **Note**: If you're not in a hurry, you can let Traefik obtain fresh certificates:

```bash
# Start with empty acme.json
cd /mnt/fast/apps/homelab/traefik
docker compose down
rm traefik/acme/acme.json
touch traefik/acme/acme.json
chmod 600 traefik/acme/acme.json
docker compose up -d

# Traefik will automatically request new certificates
# This takes a few minutes but avoids potential issues
```

**When to use this**: If you have time and aren't near rate limits.

## Verify Backup Before Restore

```bash
# List contents
tar -tzf /mnt/tank/backups/homelab/traefik/acme-daily-20251025-2236.tar.gz

# Extract to temp location
mkdir /tmp/traefik-test
tar -xzf /mnt/tank/backups/homelab/traefik/acme-daily-20251025-2236.tar.gz \
  -C /tmp/traefik-test/

# Check acme.json exists and has content
ls -lh /tmp/traefik-test/acme/acme.json
# Should be several KB

# Inspect certificate info (optional, requires jq)
cat /tmp/traefik-test/acme/acme.json | jq '.letsencrypt.Certificates[].domain'
# Shows all domains in the backup
```

## Disaster Recovery

To restore Traefik certificates on a new server:

1. Install Docker and Docker Compose
2. Copy compose.yml and traefik.yml from `/mnt/fast/apps/homelab/traefik/`
3. Create directory structure:
   ```bash
   mkdir -p /mnt/fast/apps/homelab/traefik/traefik/acme
   ```
4. Restore certificates from backup
5. **Important**: Ensure DNS points to new server BEFORE starting Traefik
6. Start Traefik
7. Certificates will work immediately (no re-issuance needed)

## Troubleshooting

### "Certificate has expired" warnings

Check certificate expiry dates:

```bash
# View certificate details
docker exec traefik cat /acme.json | jq '.letsencrypt.Certificates[].domain'

# Check expiry
curl -I https://yourdomain.com 2>&1 | grep -i certificate
```

If expired:
```bash
# Remove old certificates and let Traefik re-issue
cd /mnt/fast/apps/homelab/traefik
docker compose down
rm traefik/acme/acme.json
touch traefik/acme/acme.json
chmod 600 traefik/acme/acme.json
docker compose up -d
```

### "Permission denied" or "acme.json too open"

```bash
# Fix permissions (MUST be 600)
sudo chmod 600 /mnt/fast/apps/homelab/traefik/traefik/acme/acme.json
sudo chown root:root /mnt/fast/apps/homelab/traefik/traefik/acme/acme.json

# Restart Traefik
docker compose restart
```

### Traefik requesting new certificates despite restore

**Possible causes**:
1. acme.json not in correct location
2. Wrong permissions on acme.json
3. Certificates in backup are expired
4. DNS not pointing to this server

**Solutions**:
```bash
# Check acme.json location
ls -l /mnt/fast/apps/homelab/traefik/traefik/acme/acme.json

# Verify in docker volume mapping (compose.yml)
grep acme /mnt/fast/apps/homelab/traefik/compose.yaml

# Check Traefik logs for details
docker logs traefik | grep -i acme
```

### "Rate limit exceeded" error

If you hit Let's Encrypt rate limits:

1. **Wait**: Rate limits reset after 1 week
2. **Use backup**: Restore certificates from backup to avoid re-issuing
3. **Use staging**: Temporarily switch to staging environment for testing

## Let's Encrypt Rate Limits

**Awareness**: Let's Encrypt has rate limits:
- 50 certificates per registered domain per week
- 5 duplicate certificates per week (same set of domains)

**Why backup matters**: Restoring from backup avoids triggering rate limits during server rebuilds or testing.

## Important Notes

- **acme.json permissions**: MUST be 600 (rw-------) for security
- **Contains private keys**: Protect this file - it contains certificate private keys
- **Small file**: Typically under 100KB even with many domains
- **Account key included**: Backup includes Let's Encrypt account key
- **Wildcard certs**: If using wildcard certificates, they're all in this one file
- **Automatic renewal**: Once restored, Traefik handles automatic renewal

## Best Practices

1. **Backup regularly**: SSL certificates can't be re-issued quickly due to rate limits
2. **Test restores**: Periodically test certificate restoration
3. **Keep secure**: acme.json contains private keys - treat like passwords
4. **Monitor expiry**: Certificates expire after 90 days
5. **Verify renewals**: Check that automatic renewal is working
