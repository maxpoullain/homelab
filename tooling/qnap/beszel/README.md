# Beszel Agent Installation on QNAP TS-431

## Table of Contents

- [Overview](#overview)
  - [System Information](#system-information)
  - [How It Connects](#how-it-connects)
  - [What Is Monitored](#what-is-monitored)
- [Installation Steps](#installation-steps)
  - [1. Download the Agent Static Binary](#1-download-the-agent-static-binary)
  - [2. Install the Agent on the QNAP](#2-install-the-agent-on-the-qnap)
  - [3. Install the Hub Public Key](#3-install-the-hub-public-key)
  - [4. Test in the Foreground](#4-test-in-the-foreground)
  - [5. Register with QNAP's QPKG System](#5-register-with-qnaps-qpkg-system)
  - [6. Start the Agent](#6-start-the-agent)
  - [7. Add the System in the Hub](#7-add-the-system-in-the-hub)
- [S.M.A.R.T. and Temperatures](#smart-and-temperatures)
  - [Bundled smartctl](#bundled-smartctl)
  - [Temperatures](#temperatures)
  - [Fan speed](#fan-speed)
  - [RAID warning](#raid-warning)
- [Usage](#usage)
  - [Start/Stop/Restart](#startstoprestart)
  - [View Logs](#view-logs)
  - [Debug Run](#debug-run)
- [File Structure](#file-structure)
- [Configuration](#configuration)
- [Troubleshooting](#troubleshooting)
  - [Agent Not Running After Reboot](#agent-not-running-after-reboot)
  - [Hub Shows the System as Down](#hub-shows-the-system-as-down)
  - [Wrong Disk Shown](#wrong-disk-shown)
  - [RAID Shows a Warning](#raid-shows-a-warning)
  - [Exec Format Error / "not found" Running the Binary](#exec-format-error--not-found-running-the-binary)
  - [`scp: subsystem request failed`](#scp-subsystem-request-failed)
  - [Port Already in Use](#port-already-in-use)
  - [Agent Killed Every ~30 Seconds, or Two Agents Running](#agent-killed-every-30-seconds-or-two-agents-running)
- [Updating the Agent](#updating-the-agent)
- [Uninstallation](#uninstallation)
- [Notes](#notes)
- [Version Compatibility](#version-compatibility)
- [Support](#support)


## Overview

This guide documents how to install and run the [Beszel](https://beszel.dev) agent on a QNAP TS-431 NAS running an older QTS version (< 5.0). There is no systemd and no Docker on this box, so neither the official install script nor the container image can be used. The agent is a single static Go binary, so it is installed the same way as [Tailscale](../tailscale/README.md): a binary, a startup script and a QPKG registration.

The Beszel hub connects **to** the agent over SSH, using the NAS's **Tailscale IP**, not its LAN IP.

### System Information

- **Device**: QNAP TS-431
- **Architecture**: ARM v7 (Cortex-A9, VFPv3 + NEON)
- **QTS Version**: 4.3.6
- **Kernel**: 3.2.26
- **RAM**: 480 MB (the agent uses about 6 MB)
- **Beszel Version**: 0.21.0 (static ARMv7 binary, same version as the hub)
- **Prerequisite**: Tailscale running on the NAS, see [../tailscale/README.md](../tailscale/README.md)

### How It Connects

- The agent runs in **SSH mode**: the hub dials the agent, the agent never calls out. It needs no `TOKEN` and no `HUB_URL`.
- The agent listens on **`127.0.0.1:45876` only**. `tailscaled` runs in userspace-networking mode and hands inbound tailnet connections for its own IP to `127.0.0.1`, so the agent is reachable over Tailscale and nowhere else. The LAN IP refuses the connection by design.
- The only thing stored on the NAS is the hub's **public** key (`etc/key`). The agent's SSH server only accepts that key, and gives no shell.

### What Is Monitored

- Monitored: CPU, memory, swap, network (`eth0`), disk usage and I/O of the data volume, full S.M.A.R.T. data for the 3 disks (bundled `smartctl`, see below) and temperatures (system/board, which QNAP reports as the closest thing to a CPU temperature, and the 3 disks, see below).
- Not available: a dedicated CPU core temperature (`getsysinfo cputmp` is empty on this model), fan speed, Docker containers, systemd services, GPU, Wi-Fi.
- The load average sits around 2.3 on an idle NAS: three kernel threads are permanently in uninterruptible sleep and Linux counts them. Use the CPU % chart instead.

---

## Installation Steps

### 1. Download the Agent Static Binary

On a modern computer (not the QNAP). **Use `armv7`, not `arm64`** — the TS-431 is a 32-bit ARMv7 device; an arm64 binary will fail with "Exec format error".

```bash
VER=0.21.0

# Download the ARM v7 static binary + the release checksums
wget https://github.com/henrygd/beszel/releases/download/v${VER}/beszel-agent_linux_armv7.tar.gz
wget https://github.com/henrygd/beszel/releases/download/v${VER}/beszel_${VER}_checksums.txt

# Verify and extract
grep ' beszel-agent_linux_armv7.tar.gz$' beszel_${VER}_checksums.txt | sha256sum -c -
tar xzf beszel-agent_linux_armv7.tar.gz beszel-agent
```

### 2. Install the Agent on the QNAP

**Do not stage through `/tmp` on the QNAP** — it's a 64 MB RAM disk. Copy straight to the final location instead:

```bash
B=/share/CACHEDEV1_DATA/.qpkg/beszel-agent

# Create installation directories on the QNAP (etc holds the hub key)
ssh admin@YOUR-QNAP-IP "mkdir -p $B/bin $B/etc $B/var && chmod 700 $B/etc"

# Copy the binary + init script directly into place
scp beszel-agent admin@YOUR-QNAP-IP:$B/bin/
scp beszel_init.sh admin@YOUR-QNAP-IP:$B/
# If scp fails with "subsystem request failed": add -O (OpenSSH 9+ defaults to SFTP)

# Make them executable and sanity check before registering anything
ssh admin@YOUR-QNAP-IP "chmod +x $B/bin/beszel-agent $B/beszel_init.sh && $B/bin/beszel-agent -v"
```

### 3. Install the Hub Public Key

The agent only accepts the hub's key. It is the same public key for every system, shown in the hub's **Add System** dialog. Write it straight to the NAS (it never touches your local disk). Example if the hub's environment is kept in a sops-encrypted file with a `KEY=` line:

```bash
sops -d YOUR-HUB-ENV-FILE | sed -n 's/^KEY=//p' | tr -d '"' \
  | ssh admin@YOUR-QNAP-IP "umask 077; cat > $B/etc/key"
```

### 4. Test in the Foreground

SSH into the QNAP and run the agent with debug logging (Ctrl+C to quit):

```bash
/share/CACHEDEV1_DATA/.qpkg/beszel-agent/beszel_init.sh foreground
```

Expect these lines (the debug lines about no `smartctl`, no temperature sensors and no fans are normal on this NAS):

```
INFO Detected disk name=Data device=/dev/mapper/cachedev1 mount=/share/CACHEDEV1_DATA io=dm-1 root=true
INFO Detected network interface name=eth0 ...
INFO Starting SSH server addr=127.0.0.1:45876 network=tcp
```

If the disk line shows another device, or `Root I/O unmapped`, see [Wrong Disk Shown](#wrong-disk-shown).

### 5. Register with QNAP's QPKG System

Add the agent to the QNAP package configuration, same as Tailscale:

```bash
VER=0.21.0
B=/share/CACHEDEV1_DATA/.qpkg/beszel-agent

# Keep a copy of the registry first
cp /etc/config/qpkg.conf $B/var/qpkg.conf.bak

# Register the agent as a QPKG
/sbin/setcfg beszel-agent Name beszel-agent -f /etc/config/qpkg.conf
/sbin/setcfg beszel-agent Display_Name "Beszel Agent" -f /etc/config/qpkg.conf
/sbin/setcfg beszel-agent Version $VER -f /etc/config/qpkg.conf
/sbin/setcfg beszel-agent Enable TRUE -f /etc/config/qpkg.conf
/sbin/setcfg beszel-agent Date $(date +%Y-%m-%d) -f /etc/config/qpkg.conf
/sbin/setcfg beszel-agent Shell $B/beszel_init.sh -f /etc/config/qpkg.conf
/sbin/setcfg beszel-agent Install_Path $B -f /etc/config/qpkg.conf
/sbin/setcfg beszel-agent QPKG_File beszel-agent -f /etc/config/qpkg.conf
/sbin/setcfg beszel-agent RC_Number 109 -f /etc/config/qpkg.conf
/sbin/setcfg beszel-agent Status complete -f /etc/config/qpkg.conf
/sbin/setcfg beszel-agent Author "Manual Install" -f /etc/config/qpkg.conf

# Create startup symlinks
/sbin/qpkg --set-rc-seq
```

Verify the registration:

```bash
grep -A 12 "\[beszel-agent\]" /etc/config/qpkg.conf
ls -la /etc/rcS.d/ | grep beszel   # QS108beszel-agent, the number comes from --set-rc-seq
```

### 6. Start the Agent

```bash
/share/CACHEDEV1_DATA/.qpkg/beszel-agent/beszel_init.sh start
/share/CACHEDEV1_DATA/.qpkg/beszel-agent/beszel_init.sh status
```

From any other device on the tailnet, check that the agent answers on the Tailscale IP. It should print the SSH banner:

```bash
nc -w 3 YOUR-QNAP-TAILSCALE-IP 45876 </dev/null | head -c 30   # SSH-2.0-beszel_0.21.0
```

### 7. Add the System in the Hub

In the hub web UI click **Add System** and fill in:

- **Name**: any name, e.g. the NAS hostname
- **Host / IP**: the NAS's Tailscale IP (`YOUR-QNAP-TAILSCALE-IP`)
- **Port**: `45876`

Ignore the Docker / binary install snippets in the dialog, the agent is already running. Use the Tailscale IP, not the LAN IP: the agent listens on loopback only, so the LAN IP refuses the connection.

---

## S.M.A.R.T. and Temperatures

### Bundled smartctl

QTS 4.x has no `smartctl`. Entware publishes smartmontools 7.5 for `armv7-3.2` (kernel 3.2+) and it works on this NAS, but it needs Entware's glibc 2.27, so both are bundled in `smartctl/` and run through `smartctl-wrapper.sh` (installed as `smartctl/bin/smartctl`). Entware itself is not installed. Build it on a modern machine:

```bash
F=https://bin.entware.net/armv7sf-k3.2
curl -fsSL $F/Packages.gz | gunzip > Packages
# download and unpack these .ipk files (Filename: field in Packages):
#   smartmontools smartmontools-drivedb libc libssp librt libpthread libstdcpp libgcc
# each .ipk is an ar/tar archive holding data.tar.gz with an opt/ tree
mkdir -p smartctl/lib smartctl/bin smartctl/share
# opt/lib/* of every package          -> smartctl/lib/
# opt/sbin/smartctl                   -> smartctl/bin/smartctl.real
# opt/share/smartmontools/drivedb.h   -> smartctl/share/
cp smartctl-wrapper.sh smartctl/bin/smartctl && chmod +x smartctl/bin/smartctl smartctl/lib/ld-2.27.so
tar czf - smartctl | ssh admin@YOUR-QNAP-IP "tar xzf - -C $B"
```

Check it on the NAS: `$B/smartctl/bin/smartctl -d sat -H /dev/sda`. The disks must be read with `-d sat`, the default `scsi` type returns almost nothing, so `SMART_DEVICES` in `beszel_init.sh` lists them explicitly. Standby is disabled on this NAS, so reading attributes never wakes a disk. No auto-update: bump the bundle by hand.

The hub fetches S.M.A.R.T. data when a system first comes online and then hourly, and doesn't retry a *successful* fetch sooner. After changing the S.M.A.R.T. setup, restart the hub (`docker restart YOUR-HUB-CONTAINER`) to get data immediately.

### Temperatures

The kernel has no `/sys/class/hwmon`. `beszel_init.sh` builds a fake one in `/tmp/beszel-fakesys` (`SYS_SENSORS`) and refreshes it every 30 seconds from QNAP's `getsysinfo`: `system_board` (`systmp`) and `disk_sda`/`disk_sdb`/`disk_sdc` (`hdtmp N`). `getsysinfo cputmp` prints nothing on the TS-431; if a model reports it, it shows up as `cpu_package` automatically.

### Fan speed

Not available. The TS-431 has one fan driven through a PIC microcontroller, and QNAP's own tools report no usable RPM for it (`getsysinfo sysfannum` returns 0, `sysfan 1` returns `-1 RPM`). The agent only reads fans from the real `/sys/class/hwmon`, so the fake sensor tree can't feed it either. The "fan management" setting in the QTS UI only sets a speed policy. Don't run `fan_test`, it is a factory tool and hangs.

### RAID warning

`md1` is reported with a `WARNING` while `/sys/block/md1/md/mismatch_cnt` is non-zero. The counter only resets when a scrub runs, it never clears by itself. QTS 4.3 offers no scrub in its UI ("Check File System" is an fsck of the volume). Run one over SSH, it is read-only and takes hours:

```bash
echo check > /sys/block/md1/md/sync_action
cat /proc/mdstat                          # progress
cat /sys/block/md1/md/mismatch_cnt        # result, 0 means clean
```

---

## Usage

### Start/Stop/Restart

```bash
B=/share/CACHEDEV1_DATA/.qpkg/beszel-agent

# Start the agent
$B/beszel_init.sh start

# Stop the agent
$B/beszel_init.sh stop

# Restart the agent
$B/beszel_init.sh restart

# Check status (version, supervisor and agent PIDs, memory, listening socket)
$B/beszel_init.sh status
```

### View Logs

```bash
# Follow the agent log
$B/beszel_init.sh log

# Or directly:
tail -f $B/var/beszel-agent.log

# View boot/startup log (one line per agent launch, so relaunches show up here)
$B/beszel_init.sh bootlog
```

### Debug Run

```bash
# Stop the service first, then run in the foreground with debug logging
$B/beszel_init.sh stop
$B/beszel_init.sh foreground

# One-off setting changes work too, e.g. listen on all interfaces
LISTEN=45876 $B/beszel_init.sh foreground
```

---

## File Structure

```
/share/CACHEDEV1_DATA/.qpkg/beszel-agent/
├── bin/
│   └── beszel-agent          # Beszel agent (static ARMv7 binary)
├── smartctl/                 # Bundled smartctl + glibc, see S.M.A.R.T. section
├── etc/
│   └── key                   # Hub public key (mode 600)
├── var/
│   ├── beszel-agent.log      # Agent log (rotated at 1 MB, one .old kept)
│   ├── boot.log              # Startup script log
│   ├── supervisor.pid        # PID of the supervisor loop
│   └── qpkg.conf.bak         # qpkg.conf as it was before registration
└── beszel_init.sh            # Startup/control script
```

```
/etc/config/qpkg.conf         # QPKG registry (persists across reboots)
/etc/rcS.d/QS*beszel-agent    # Startup symlink (auto-created on boot, exact
                              # sequence number comes from `qpkg --set-rc-seq`)
/etc/init.d/beszel_init.sh    # Init.d symlink (auto-created on boot)
```

---

## Configuration

The agent is configured with environment variables, set in `agent_env()` at the top of `beszel_init.sh`. Edit them on the NAS and run `restart`. Every default can also be overridden for a one-off `foreground` run.

- `KEY_FILE`: the hub public key, `etc/key`.
- `DATA_DIR`: `var/`. The agent keeps its identity file there, which matters if WebSocket mode is ever used. `/` is a RAM disk on QTS, so it must be on the data volume.
- `LISTEN=127.0.0.1:45876`: loopback only, see [How It Connects](#how-it-connects). Use `LISTEN=45876` to listen on all interfaces, for example to add the system by LAN IP.
- `FILESYSTEM=/share/CACHEDEV1_DATA__Data`: `/` is a 61 MB RAM disk, so this makes the data volume the main disk. The `__Data` suffix is the display name in the hub.
- `EXCLUDE_SMART=/dev/md1,/dev/md9,/dev/md13,/dev/md256,/dev/md322`: hides every md array. `md9` and `md13` have 24 slots with 3 used, which Beszel reports as a permanent warning, and `md256`/`md322` are swap mirrors. `md1` (data) is hidden too because its stale `mismatch_cnt` gives a permanent warning; the disks are covered by S.M.A.R.T. Remove it from the list to monitor the array state again. Check `cat /proc/mdstat` after any disk change.
- `DOCKER_HOST=""`, `SKIP_GPU`, `SKIP_SYSTEMD`, `SKIP_WIFI`: nothing to monitor here, so the agent skips these probes.
- `LOG_LEVEL=info`.

See the [Beszel environment variables](https://beszel.dev/guide/environment-variables) for the full list.

---

## Troubleshooting

### Agent Not Running After Reboot

Give it time first: QTS only runs the package start scripts about 10 minutes after the kernel boots (after the volumes are mounted), and the Tailscale script adds a 30 second delay. A full reboot was tested: both Tailscale and the agent came back by themselves, and the system showed up again in the hub without any action. `reboot` itself is slow too (a few minutes to shut down, about 10 to boot).

1. Check if the QPKG entry exists:

   ```bash
   grep -A 12 "\[beszel-agent\]" /etc/config/qpkg.conf
   ```

1. Check if symlinks were created:

   ```bash
   ls -la /etc/rcS.d/ | grep beszel
   ```

1. Check boot log:

   ```bash
   cat /share/CACHEDEV1_DATA/.qpkg/beszel-agent/var/boot.log
   ```

1. Manually start and check the agent log:

   ```bash
   /share/CACHEDEV1_DATA/.qpkg/beszel-agent/beszel_init.sh start
   tail -50 /share/CACHEDEV1_DATA/.qpkg/beszel-agent/var/beszel-agent.log
   ```

### Hub Shows the System as Down

1. On the NAS, `beszel_init.sh status` should show one agent listening on `127.0.0.1:45876`.

1. From another tailnet device, the Tailscale IP should answer with an SSH banner. No banner means Tailscale on the NAS is down (`tailscale_init.sh status`) or blocked by your tailnet ACLs:

   ```bash
   nc -w 3 YOUR-QNAP-TAILSCALE-IP 45876 </dev/null | head -c 30
   ```

1. The hub itself runs in a container. To test its exact path, run the same check from a container on its network:

   ```bash
   docker run --rm --network YOUR-HUB-DOCKER-NETWORK busybox sh -c 'nc -w 3 YOUR-QNAP-TAILSCALE-IP 45876 </dev/null | head -c 30'
   ```

1. If the banner shows but the hub is still down, check that `etc/key` holds the hub's public key and that the system uses host `YOUR-QNAP-TAILSCALE-IP` and port `45876`.

### Wrong Disk Shown

Run `beszel_init.sh foreground` and look at the `Detected disk` line. It should name `/dev/mapper/cachedev1` with `io=dm-1` and `root=true`. If the hub shows a 61 MB disk, or the log says `Root I/O unmapped; set FILESYSTEM`, adjust `FILESYSTEM`: the part before `__` is a mount point (`/share/CACHEDEV1_DATA`) or a device name from `/proc/diskstats`.

### RAID Shows a Warning

A `WARNING` on `md1` while `cat /proc/mdstat` shows a `resync` or `recovery` in progress is expected and clears on its own. A `FAILED` state means a member disk is faulty.

### Exec Format Error / "not found" Running the Binary

Wrong architecture. Run `uname -m` on the QNAP — it should print `armv7l`. Use the `armv7` tarball, not `arm64`.

### `scp: subsystem request failed`

Your SSH client defaults to SFTP. Add `-O` to fall back to the old scp protocol: `scp -O ...`.

### Port Already in Use

The agent logs `address already in use` when something else holds port 45876, typically a second agent:

```bash
netstat -tln | grep 45876
pidof beszel-agent   # should print exactly one PID
```

If it prints more, `stop`, check `pidof beszel-agent` is empty, then `start`.

### Agent Killed Every ~30 Seconds, or Two Agents Running

The agent is deliberately **not** registered with QNAP's `daemon_mgr` watchdog, see [Notes](#notes). If `/etc/daemon_mgr.conf` contains a `beszel-agent` line (for example from an older script, or from running `daemon_mgr beszel-agent ...` by hand), the watchdog kills the process about every 30 seconds when that entry is `stop`, and launches a second copy when it is `start`. The file lives in RAM, so a reboot also clears it. To remove the entry without rebooting:

```bash
cp /etc/daemon_mgr.conf /tmp/daemon_mgr.conf.bak
grep -v '^DAEMON[0-9]* = beszel-agent, ' /etc/daemon_mgr.conf > /tmp/dm.new
cat /tmp/dm.new > /etc/daemon_mgr.conf && rm /tmp/dm.new
```

---

## Updating the Agent

Update the agent right after the hub image is updated, so both run the same version. Run this **from your workstation** (not on the NAS), after setting `VER` to the hub's version (`docker inspect YOUR-HUB-CONTAINER --format '{{index .Config.Labels "org.opencontainers.image.version"}}'` on the hub host):

```bash
VER=0.21.0
NAS=admin@YOUR-QNAP-IP
B=/share/CACHEDEV1_DATA/.qpkg/beszel-agent

# 1. Download and verify (the "armv7" build, never arm64)
curl -fsSLO https://github.com/henrygd/beszel/releases/download/v${VER}/beszel-agent_linux_armv7.tar.gz
curl -fsSLO https://github.com/henrygd/beszel/releases/download/v${VER}/beszel_${VER}_checksums.txt
awk '$2=="beszel-agent_linux_armv7.tar.gz"' beszel_${VER}_checksums.txt | sha256sum -c -
tar xzf beszel-agent_linux_armv7.tar.gz beszel-agent

# 2. Stop, replace, start. The new binary goes straight to its final place, not via /tmp
ssh $NAS "$B/beszel_init.sh stop"
scp -O beszel-agent $NAS:$B/bin/beszel-agent
ssh $NAS "chmod +x $B/bin/beszel-agent && /sbin/setcfg beszel-agent Version $VER -f /etc/config/qpkg.conf && $B/beszel_init.sh start && sleep 4 && $B/beszel_init.sh status"
```

`status` should print `beszel-agent $VER` and one listening agent. The hub shows the system as up again within a minute. If `beszel_init.sh` itself changed in the repo, copy it too (`scp -O beszel_init.sh $NAS:$B/`) before the `start`.

`beszel-agent update` (self-update from GitHub) is not used here and has not been tested on QTS. The bundled `smartctl` doesn't need updating with the agent, see [Bundled smartctl](#bundled-smartctl).

---

## Uninstallation

To completely remove the agent, first delete this NAS's system in the hub, then on the NAS:

```bash
# Stop the agent
/share/CACHEDEV1_DATA/.qpkg/beszel-agent/beszel_init.sh stop

# Remove from QPKG registry
/sbin/rmcfg beszel-agent -f /etc/config/qpkg.conf

# Remove files
rm -rf /share/CACHEDEV1_DATA/.qpkg/beszel-agent

# Remove symlinks (will be recreated on boot, but without the agent)
rm -f /etc/rcS.d/QS*beszel-agent
rm -f /etc/init.d/beszel_init.sh
```

---

## Notes

- `/etc/config/qpkg.conf` is stored in `/mnt/HDA_ROOT/.config/` and persists across reboots
- `/etc/init.d/` and `/etc/rcS.d/` are recreated on each boot based on `qpkg.conf`
- `/tmp` on the QNAP is a 64 MB RAM disk — don't stage binaries there, copy straight into `/share/CACHEDEV1_DATA/`
- Always store scripts and data in `/share/CACHEDEV1_DATA/` for persistence
- Unlike Tailscale, the agent is **not** started through `daemon_mgr`. On a `start` that follows a `stop`, `daemon_mgr` kills the agent 20-30 seconds later and launches its own copy, while the `daemon_mgr` client that launched the first one relaunches it too. Tailscale tolerates this because the second `tailscaled` exits, but the Beszel agent keeps retrying its port every 10 seconds, so both copies survive. Instead, `start` launches a small supervisor loop (the `supervise` action of `beszel_init.sh`, in its own session) that relaunches the agent 10 seconds after it exits for any reason
- The same loop covers boot persistence: QTS runs `beszel_init.sh start` through the `QS108beszel-agent` symlink on every boot, and no boot delay is needed because the agent only listens on loopback
- The agent log is rotated before every launch once it passes 1 MB, one `.old` generation is kept
- SSH mode needs no secret: `etc/key` is a public key, kept at mode 600 anyway

---

## Version Compatibility

Keep the agent on the same version as the hub (check it with `docker inspect YOUR-HUB-CONTAINER --format '{{index .Config.Labels "org.opencontainers.image.version"}}'`), and update the agent whenever the hub image is updated. Before bumping, check the [Go minimum requirements](https://go.dev/wiki/MinimumRequirements) against this NAS's kernel (`uname -r`) — newer Beszel releases bump the Go toolchain, and Go 1.24+ needs Linux 3.2 or later (this NAS runs 3.2.26, as for Tailscale).

---

## Support

For Beszel-specific issues, consult:

- Beszel Documentation: https://beszel.dev/guide/what-is-beszel
- Beszel Issues: https://github.com/henrygd/beszel/issues

For QNAP-specific issues, consult QNAP support or forums.
