# Tailscale Installation on QNAP TS-431

## Table of Contents

- [Overview](#overview)
  - [System Information](#system-information)
  - [Limitations](#limitations)
- [Installation Steps](#installation-steps)
  - [1. Download Tailscale Static Binary](#1-download-tailscale-static-binary)
  - [2. Install Tailscale on QNAP](#2-install-tailscale-on-qnap)
  - [3. Register with QNAP's QPKG System](#3-register-with-qnaps-qpkg-system)
  - [4. Authenticate Tailscale](#4-authenticate-tailscale)
- [Usage](#usage)
  - [Start/Stop/Restart](#startstoprestart)
  - [Check Connection Status](#check-connection-status)
  - [View Logs](#view-logs)
- [File Structure](#file-structure)
- [Troubleshooting](#troubleshooting)
  - [Tailscale Not Running After Reboot](#tailscale-not-running-after-reboot)
  - [Socket Already in Use Error](#socket-already-in-use-error)
  - [DNS Warning](#dns-warning)
  - [Exec Format Error / "not found" Running the Binary](#exec-format-error--not-found-running-the-binary)
  - [`scp: subsystem request failed`](#scp-subsystem-request-failed)
  - [Two `tailscaled` Processes Running (`pidof tailscaled` shows 2 PIDs)](#two-tailscaled-processes-running-pidof-tailscaled-shows-2-pids)
  - [Slow Performance](#slow-performance)
- [Updating Tailscale](#updating-tailscale)
- [Uninstallation](#uninstallation)
- [Notes](#notes)
- [Version Compatibility](#version-compatibility)
- [Support](#support)


## Overview

This guide documents how to install and run Tailscale on a QNAP TS-431 NAS running an older QTS version (< 5.0) that doesn't support the official Tailscale QPKG.

### System Information
- **Device**: QNAP TS-431
- **Architecture**: ARM v7 (Cortex-A9)
- **QTS Version**: 4.x (older than 5.0)
- **Kernel**: 3.2.26
- **Tailscale Version**: 1.104.1 (static ARM binary)

### Limitations
- **Userspace networking only**: Kernel lacks TUN module support
- **No network namespaces**: Cannot use Docker networking features
- **VFS storage driver**: Docker overlay2 not supported
- **Performance**: Userspace networking is 30-50% slower than kernel TUN, but sufficient for typical NAS remote access

---

## Installation Steps

### 1. Download Tailscale Static Binary

On a modern computer (not the QNAP). **Use `arm`, not `arm64`** — the TS-431 is a 32-bit ARMv7 (Cortex-A9) device; an arm64 binary will fail with "Exec format error".

```bash
VER=1.104.1

# Download ARM v7 static binary + checksum
wget https://pkgs.tailscale.com/stable/tailscale_${VER}_arm.tgz
wget https://pkgs.tailscale.com/stable/tailscale_${VER}_arm.tgz.sha256

# Verify and extract
echo "$(cat tailscale_${VER}_arm.tgz.sha256)  tailscale_${VER}_arm.tgz" | sha256sum -c -
tar xzf tailscale_${VER}_arm.tgz
```

### 2. Install Tailscale on QNAP

**Do not stage through `/tmp` on the QNAP** — it's a 64 MB RAM disk and the two binaries together are ~70 MB, so a large transfer there will be silently truncated. Copy straight to the final location instead:

```bash
# Create installation directories on the QNAP
ssh admin@YOUR-QNAP-IP 'mkdir -p /share/CACHEDEV1_DATA/.qpkg/tailscale/bin /share/CACHEDEV1_DATA/.qpkg/tailscale/var'

# Copy the binaries + init script directly into place
scp tailscale_${VER}_arm/tailscale tailscale_${VER}_arm/tailscaled \
  admin@YOUR-QNAP-IP:/share/CACHEDEV1_DATA/.qpkg/tailscale/bin/
scp tailscale_init.sh admin@YOUR-QNAP-IP:/share/CACHEDEV1_DATA/.qpkg/tailscale/
# If scp fails with "subsystem request failed": add -O (OpenSSH 9+ defaults to SFTP)
```

SSH into your QNAP and finish setup:

```bash
TS=/share/CACHEDEV1_DATA/.qpkg/tailscale
chmod +x $TS/bin/tailscale $TS/bin/tailscaled $TS/tailscale_init.sh

# Sanity check before registering anything
$TS/bin/tailscaled --version
```

### 3. Register with QNAP's QPKG System

Add Tailscale to the QNAP package configuration:

```bash
VER=1.104.1

# Register Tailscale as a QPKG
/sbin/setcfg tailscale Name tailscale -f /etc/config/qpkg.conf
/sbin/setcfg tailscale Display_Name "Tailscale VPN" -f /etc/config/qpkg.conf
/sbin/setcfg tailscale Version $VER -f /etc/config/qpkg.conf
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

### 4. Authenticate Tailscale

Start Tailscale and authenticate:

```bash
# Start Tailscale
/share/CACHEDEV1_DATA/.qpkg/tailscale/tailscale_init.sh start

# Get authentication URL (--hostname sets the name shown in the admin console)
/share/CACHEDEV1_DATA/.qpkg/tailscale/bin/tailscale \
  --socket=/var/run/tailscale/tailscaled.sock up --hostname=cache

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

**Reinstalling a device that already exists in your tailnet?** A fresh install creates a new node — it does not reuse the old one. Before (or right after) authenticating:
- Delete the old node in the [admin console](https://login.tailscale.com/admin/machines) first, otherwise the new one registers as `<hostname>-1`.
- If anything depends on this device's Tailscale IP (e.g. a reverse proxy route), edit the IPv4 address back to the old one from the device's `⋯` menu.
- Re-enable **Disable key expiry** if the old node had it set — this does not carry over.

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
/etc/rcS.d/QS*tailscale    # Startup symlink (auto-created on boot, exact
                           # sequence number comes from `qpkg --set-rc-seq`)
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

### Exec Format Error / "not found" Running the Binary

Wrong architecture. Run `uname -m` on the QNAP — it should print `armv7l`. Use the `arm` tarball, not `arm64`.

### `scp: subsystem request failed`

Your SSH client defaults to SFTP. Add `-O` to fall back to the old scp protocol: `scp -O ...`.

### Two `tailscaled` Processes Running (`pidof tailscaled` shows 2 PIDs)

QNAP's `daemon_mgr` watchdog polls `/etc/daemon_mgr.conf` every ~30s and relaunches any registered daemon it doesn't see running — independently of this script. If a stale entry exists there (e.g. from a previous install) and you then run `start`, you can end up with two daemons: the watchdog's and the script's. The script's own stale-socket cleanup can orphan whichever one started first.

`tailscale_init.sh` guards against this (`start` is a no-op if a daemon is already running), so this should only happen with an older copy of the script. Fix:
```bash
/share/CACHEDEV1_DATA/.qpkg/tailscale/tailscale_init.sh stop
sleep 5   # let the watchdog's next poll settle
pidof tailscaled   # should print nothing
/share/CACHEDEV1_DATA/.qpkg/tailscale/tailscale_init.sh start
pidof tailscaled   # should print exactly one PID
```

### Slow Performance

Userspace networking is 30-50% slower than kernel TUN mode, but this is normal given the kernel limitations. For typical NAS operations (file access, web UI), this should not be noticeable.

---

## Updating Tailscale

To update to a newer version, repeat **step 1** with the new `VER`, then:

1. Stop Tailscale:
   ```bash
   /share/CACHEDEV1_DATA/.qpkg/tailscale/tailscale_init.sh stop
   ```

2. Replace binaries (straight to their final location, not via `/tmp` — see step 2 above):
   ```bash
   scp tailscale_${VER}_arm/tailscale tailscale_${VER}_arm/tailscaled \
     admin@YOUR-QNAP-IP:/share/CACHEDEV1_DATA/.qpkg/tailscale/bin/
   ssh admin@YOUR-QNAP-IP 'chmod +x /share/CACHEDEV1_DATA/.qpkg/tailscale/bin/*'
   ```

3. Update version in qpkg.conf:
   ```bash
   /sbin/setcfg tailscale Version $VER -f /etc/config/qpkg.conf
   ```

4. Restart:
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
rm -f /etc/rcS.d/QS*tailscale
rm -f /etc/init.d/tailscale_init.sh

# Clean up socket
rm -f /var/run/tailscale/tailscaled.sock
```

---

## Notes

- `/etc/config/qpkg.conf` is stored in `/mnt/HDA_ROOT/.config/` and persists across reboots
- `/etc/init.d/` and `/etc/rcS.d/` are recreated on each boot based on `qpkg.conf`
- `/tmp` on the QNAP is a 64 MB RAM disk — don't stage binaries there, copy straight into `/share/CACHEDEV1_DATA/`
- Always store scripts and data in `/share/CACHEDEV1_DATA/` for persistence
- The 30-second boot delay ensures the system is fully ready before starting Tailscale
- Tailscale state and authentication persist across reboots in `tailscaled.state`
- `/etc/daemon_mgr.conf` (QNAP's process watchdog registry) lives in RAM, not `/mnt/HDA_ROOT/.config/` — it's rebuilt each boot, so a stale entry from a previous install doesn't survive a reboot

---

## Version Compatibility

Tailscale has excellent backward/forward compatibility with other tailnet devices. Before bumping the version, check the [Go minimum requirements](https://go.dev/wiki/MinimumRequirements) against this NAS's kernel (`uname -r`) — newer Tailscale releases bump the Go toolchain, and Go 1.24+ needs Linux 3.2 or later.

---

## Support

For Tailscale-specific issues, consult:
- Tailscale Documentation: https://tailscale.com/kb/
- Tailscale Community: https://forum.tailscale.com/

For QNAP-specific issues, consult QNAP support or forums.