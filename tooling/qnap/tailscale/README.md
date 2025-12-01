# Tailscale Installation on QNAP TS-431

## Overview

This guide documents how to install and run Tailscale on a QNAP TS-431 NAS running an older QTS version (< 5.0) that doesn't support the official Tailscale QPKG.

### System Information
- **Device**: QNAP TS-431
- **Architecture**: ARM v7 (Cortex-A9)
- **QTS Version**: 4.x (older than 5.0)
- **Kernel**: 3.2.26
- **Tailscale Version**: 1.90.6 (static ARM binary)

### Limitations
- **Userspace networking only**: Kernel lacks TUN module support
- **No network namespaces**: Cannot use Docker networking features
- **VFS storage driver**: Docker overlay2 not supported
- **Performance**: Userspace networking is 30-50% slower than kernel TUN, but sufficient for typical NAS remote access

---

## Installation Steps

### 1. Download Tailscale Static Binary

On a modern computer (not the QNAP):

```bash
# Download ARM v7 static binaries
wget https://pkgs.tailscale.com/stable/tailscale_1.90.6_arm.tgz

# Transfer to QNAP
scp tailscale_1.90.6_arm.tgz admin@YOUR-QNAP-IP:/tmp/
```

### 2. Install Tailscale on QNAP

SSH into your QNAP and run:

```bash
# Extract the archive
cd /tmp
tar xzf tailscale_1.90.6_arm.tgz

# Create installation directory
mkdir -p /share/CACHEDEV1_DATA/.qpkg/tailscale/bin
mkdir -p /share/CACHEDEV1_DATA/.qpkg/tailscale/var

# Copy binaries
cp tailscale_1.90.6/tailscale /share/CACHEDEV1_DATA/.qpkg/tailscale/bin/
cp tailscale_1.90.6/tailscaled /share/CACHEDEV1_DATA/.qpkg/tailscale/bin/
chmod +x /share/CACHEDEV1_DATA/.qpkg/tailscale/bin/*

# Clean up
rm -rf /tmp/tailscale_*
```

### 3. Install the Startup Script

Copy the `tailscale_init.sh` script to:
```bash
/share/CACHEDEV1_DATA/.qpkg/tailscale/tailscale_init.sh
```

Make it executable:
```bash
chmod +x /share/CACHEDEV1_DATA/.qpkg/tailscale/tailscale_init.sh
```

### 4. Register with QNAP's QPKG System

Add Tailscale to the QNAP package configuration:

```bash
# Register Tailscale as a QPKG
/sbin/setcfg tailscale Name tailscale -f /etc/config/qpkg.conf
/sbin/setcfg tailscale Display_Name "Tailscale VPN" -f /etc/config/qpkg.conf
/sbin/setcfg tailscale Version 1.90.6 -f /etc/config/qpkg.conf
/sbin/setcfg tailscale Enable TRUE -f /etc/config/qpkg.conf
/sbin/setcfg tailscale Date $(date +%Y-%m-%d) -f /etc/config/qpkg.conf
/sbin/setcfg tailscale Shell /share/CACHEDEV1_DATA/.qpkg/tailscale/tailscale_init.sh -f /etc/config/qpkg.conf
/sbin/setcfg tailscale Install_Path /share/CACHEDEV1_DATA/.qpkg/tailscale -f /etc/config/qpkg.conf
/sbin/setcfg tailscale QPKG_File tailscale -f /etc/config/qpkg.conf
/sbin/setcfg tailscale RC_Number 108 -f /etc/config/qpkg.conf
/sbin/setcfg tailscale Status complete -f /etc/config/qpkg.conf
/sbin/setcfg tailscale Author "Manual Install" -f /etc/config/qpkg.conf

# Create startup symlinks
/sbin/qpkg --set-rc-seq
```

Verify the registration:
```bash
cat /etc/config/qpkg.conf | grep -A 12 "\[tailscale\]"
ls -la /etc/rcS.d/ | grep tailscale
```

### 5. Authenticate Tailscale

Start Tailscale and authenticate:

```bash
# Start Tailscale
/share/CACHEDEV1_DATA/.qpkg/tailscale/tailscale_init.sh start

# Get authentication URL
/share/CACHEDEV1_DATA/.qpkg/tailscale/bin/tailscale \
  --socket=/var/run/tailscale/tailscaled.sock up

# Visit the URL shown in your browser to authenticate
```

Optional flags for authentication:
```bash
# Accept routes from other Tailscale devices
--accept-routes

# Advertise this device as an exit node
--advertise-exit-node

# Advertise subnet routes
--advertise-routes=192.168.1.0/24
```

---

## Usage

### Start/Stop/Restart

```bash
# Start Tailscale
/share/CACHEDEV1_DATA/.qpkg/tailscale/tailscale_init.sh start

# Stop Tailscale
/share/CACHEDEV1_DATA/.qpkg/tailscale/tailscale_init.sh stop

# Restart Tailscale
/share/CACHEDEV1_DATA/.qpkg/tailscale/tailscale_init.sh restart

# Check status
/share/CACHEDEV1_DATA/.qpkg/tailscale/tailscale_init.sh status
```

### Check Connection Status

```bash
# View Tailscale status
/share/CACHEDEV1_DATA/.qpkg/tailscale/bin/tailscale \
  --socket=/var/run/tailscale/tailscaled.sock status

# Get Tailscale IP address
/share/CACHEDEV1_DATA/.qpkg/tailscale/bin/tailscale \
  --socket=/var/run/tailscale/tailscaled.sock ip -4

# Ping another device
/share/CACHEDEV1_DATA/.qpkg/tailscale/bin/tailscale \
  --socket=/var/run/tailscale/tailscaled.sock ping DEVICE-NAME
```

### View Logs

```bash
# View Tailscale daemon log
/share/CACHEDEV1_DATA/.qpkg/tailscale/tailscale_init.sh log

# Or directly:
tail -f /share/CACHEDEV1_DATA/.qpkg/tailscale/var/tailscaled.log

# View boot/startup log
cat /share/CACHEDEV1_DATA/.qpkg/tailscale/var/boot.log
```

---

## File Structure

```
/share/CACHEDEV1_DATA/.qpkg/tailscale/
├── bin/
│   ├── tailscale          # Tailscale CLI
│   └── tailscaled         # Tailscale daemon
├── var/
│   ├── tailscaled.state   # Tailscale state (auth, config)
│   ├── tailscaled.log     # Daemon log
│   └── boot.log           # Startup script log
└── tailscale_init.sh      # Startup/control script
```

```
/etc/config/qpkg.conf      # QPKG registry (persists across reboots)
/etc/rcS.d/QS108tailscale  # Startup symlink (auto-created on boot)
/etc/init.d/tailscale_init.sh  # Init.d symlink (auto-created on boot)
```

---

## Troubleshooting

### Tailscale Not Running After Reboot

1. Check if the QPKG entry exists:
   ```bash
   cat /etc/config/qpkg.conf | grep -A 12 "\[tailscale\]"
   ```

2. Check if symlinks were created:
   ```bash
   ls -la /etc/rcS.d/ | grep tailscale
   ```

3. Check boot log:
   ```bash
   cat /share/CACHEDEV1_DATA/.qpkg/tailscale/var/boot.log
   ```

4. Manually start and check daemon log:
   ```bash
   /share/CACHEDEV1_DATA/.qpkg/tailscale/tailscale_init.sh start
   tail -50 /share/CACHEDEV1_DATA/.qpkg/tailscale/var/tailscaled.log
   ```

### Socket Already in Use Error

If you see "address already in use" errors:
```bash
# Clean up stale socket
rm -f /var/run/tailscale/tailscaled.sock

# Kill any orphaned processes
killall tailscaled

# Restart
/share/CACHEDEV1_DATA/.qpkg/tailscale/tailscale_init.sh start
```

### DNS Warning

The warning `"error: Tailscale failed to fetch the DNS configuration"` is normal on QNAP and can be ignored. Tailscale will manage DNS on its own.

### Slow Performance

Userspace networking is 30-50% slower than kernel TUN mode, but this is normal given the kernel limitations. For typical NAS operations (file access, web UI), this should not be noticeable.

---

## Updating Tailscale

To update to a newer version:

1. Download new static binaries
2. Stop Tailscale:
   ```bash
   /share/CACHEDEV1_DATA/.qpkg/tailscale/tailscale_init.sh stop
   ```

3. Replace binaries:
   ```bash
   cp new_tailscale /share/CACHEDEV1_DATA/.qpkg/tailscale/bin/tailscale
   cp new_tailscaled /share/CACHEDEV1_DATA/.qpkg/tailscale/bin/tailscaled
   chmod +x /share/CACHEDEV1_DATA/.qpkg/tailscale/bin/*
   ```

4. Update version in qpkg.conf:
   ```bash
   /sbin/setcfg tailscale Version X.Y.Z -f /etc/config/qpkg.conf
   ```

5. Restart:
   ```bash
   /share/CACHEDEV1_DATA/.qpkg/tailscale/tailscale_init.sh start
   ```

---

## Uninstallation

To completely remove Tailscale:

```bash
# Stop Tailscale
/share/CACHEDEV1_DATA/.qpkg/tailscale/tailscale_init.sh stop

# Remove from QPKG registry
/sbin/rmcfg tailscale -f /etc/config/qpkg.conf

# Remove files
rm -rf /share/CACHEDEV1_DATA/.qpkg/tailscale

# Remove symlinks (will be recreated on boot, but without Tailscale)
rm -f /etc/rcS.d/QS108tailscale
rm -f /etc/init.d/tailscale_init.sh

# Clean up socket
rm -f /var/run/tailscale/tailscaled.sock
```

---

## Notes

- `/etc/config/qpkg.conf` is stored in `/mnt/HDA_ROOT/.config/` and persists across reboots
- `/etc/init.d/` and `/etc/rcS.d/` are recreated on each boot based on `qpkg.conf`
- Always store scripts and data in `/share/CACHEDEV1_DATA/` for persistence
- The 30-second boot delay ensures the system is fully ready before starting Tailscale
- Tailscale state and authentication persist across reboots in `tailscaled.state`

---

## Version Compatibility

Tailscale has excellent backward/forward compatibility. This older version (1.90.6) will work fine with newer Tailscale clients on other devices. You'll miss out on newer features, but core mesh networking functionality is fully compatible.

---

## Support

For Tailscale-specific issues, consult:
- Tailscale Documentation: https://tailscale.com/kb/
- Tailscale Community: https://forum.tailscale.com/

For QNAP-specific issues, consult QNAP support or forums.