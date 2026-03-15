# HDD Fan Control

Temperature-based fan control for HDDs via PWM, using the `nct6798` sensor chip
(exposed by the `nct6775` kernel module). Temperatures are read preferentially from
the `drivetemp` kernel module, with `smartctl` as a fallback.

---

## How It Works

1. On each run the script scans `/sys/class/hwmon/hwmon*/name` to dynamically find
   the hwmon device named `nct6798` — no hardcoded paths that break after a reboot.
2. It reads drive temperatures from all hwmon devices named `drivetemp`
   (millidegree values from the kernel, no SMART polling overhead).
3. It maps the highest temperature to a PWM tier and writes the value to `pwm1`
   on the resolved hwmon path.
4. A **hysteresis guard** (default 2 °C) prevents the fan from rapidly stepping
   back down after a brief cool-down, avoiding oscillation.
5. State (current tier threshold) is persisted in `/run/hdd_fan_control_state`
   across timer invocations within the same boot.

---

## Prerequisites

### Kernel modules

| Module      | Purpose                                          |
|-------------|--------------------------------------------------|
| `nct6775`   | Exposes the `nct6798` Super I/O chip via hwmon  |
| `drivetemp` | Exposes HDD temperatures via hwmon (preferred)  |

The systemd service loads `nct6775` automatically via `ExecStartPre`. To also load
`drivetemp` on boot, add it to your modules file:

```bash
echo "drivetemp" | sudo tee /etc/modules-load.d/drivetemp.conf
```

### Optional: smartmontools (fallback only)

If no `drivetemp` hwmon entries are found the script falls back to `smartctl`:

```bash
sudo apt-get install smartmontools   # Debian/Ubuntu
sudo dnf install smartmontools       # Fedora/RHEL
sudo pacman -S smartmontools         # Arch Linux
```

---

## Temperature Curve

The fan is controlled by the following tiers. The first tier whose threshold is
≥ the current maximum drive temperature is applied.

| Max HDD Temp | PWM   | % Speed | Label     |
|--------------|-------|---------|-----------|
| ≤ 35 °C      | 30    | 12 %    | Idle      |
| ≤ 40 °C      | 60    | 24 %    | Cool      |
| ≤ 43 °C      | 100   | 35 %    | Warm      |
| ≤ 46 °C      | 145   | 55 %    | Hot       |
| ≤ 50 °C      | 190   | 75 %    | VeryHot   |
| ≤ 54 °C      | 230   | 90 %    | Critical  |
| > 54 °C      | 255   | 100 %   | Max       |

To tune the curve, edit `TEMP_CURVE` in `hdd_fan_control.sh`. Each entry is a
string `"THRESHOLD PWM LABEL"` in ascending threshold order, with `999` as the
final catch-all.

### Hysteresis

When the temperature drops and would move to a lower tier, the script only commits
to that lower tier if the temperature is at least `HYSTERESIS` (default: **1 °C**)
below the current tier's threshold. This avoids rapid fan speed oscillation around
a boundary.

The active tier threshold is saved to `/run/hdd_fan_control_state`. This file is
in `tmpfs` and is recreated on each boot — intentionally, so the fan starts fresh
after a reboot.

---

## Configuration

All configuration lives at the top of `hdd_fan_control.sh`:

```bash
HWMON_CHIP_NAME="nct6798"   # hwmon name to search for
PWM_CHANNEL="pwm1"          # PWM channel on that chip
HYSTERESIS=1                # °C guard for stepping down
HDD_DEVICES=(...)           # Fallback device list for smartctl
TEMP_CURVE=(...)            # Temperature → PWM mapping
```

---

## Installation

```bash
# 1. Copy the script
sudo cp hdd_fan_control.sh /usr/local/bin/hdd_fan_control.sh
sudo chmod +x /usr/local/bin/hdd_fan_control.sh

# 2. Copy the systemd units
sudo cp hdd-fan-control.service /etc/systemd/system/
sudo cp hdd-fan-control.timer   /etc/systemd/system/

# 3. Load drivetemp on boot (recommended)
echo "drivetemp" | sudo tee /etc/modules-load.d/drivetemp.conf

# 4. Install logrotate config
sudo cp hdd-fan-control.logrotate /etc/logrotate.d/hdd-fan-control

# 5. Enable and start the timer
sudo systemctl daemon-reload
sudo systemctl enable --now hdd-fan-control.timer
```

---

## CLI Usage

```
Usage: hdd_fan_control.sh [OPTIONS]

Options:
  -s, --status     Show current temperatures, fan speed and resolved hwmon path
  -v, --verbose    Run normally but also print detailed status to stdout
  -t, --test       Test mode — show what would be done, no changes made
  -h, --help       Show this help and temperature curve
```

### `--status` (read-only overview)

```
========================================
 HDD Fan Control — Status
========================================
HDD Temperatures (drivetemp):
  Drive 1 (/sys/class/hwmon/hwmon7): 38°C
  Drive 2 (/sys/class/hwmon/hwmon8): 36°C
  Drive 3 (/sys/class/hwmon/hwmon9): 41°C
  Drive 4 (/sys/class/hwmon/hwmon10): 39°C

  Chip hwmon path : /sys/class/hwmon/hwmon6
  Max HDD temp    : 41°C
  Target tier     : Warm (≤43°C)
  Target PWM      : 90 / 255 (35%)
  Current PWM     : 90 / 255
  Fan RPM         : 847 RPM
========================================
```

### `--test` (dry run, no root required for reading)

```bash
sudo ./hdd_fan_control.sh --test
```

Shows resolved hwmon path, all drive temperatures, and the PWM that *would* be
applied — without writing anything.

### `--verbose` (normal run with extra output)

```bash
sudo ./hdd_fan_control.sh --verbose
```

Runs the full control loop and additionally prints the same information as
`--status` to stdout after applying changes.

---

## Service Management

```bash
# Check the timer schedule
systemctl list-timers hdd-fan-control.timer

# Check the last run
systemctl status hdd-fan-control.service

# Follow logs in real time
journalctl -u hdd-fan-control.service -f

# View the script's own log file
tail -f /var/log/hdd_fan_control.log

# One-shot manual run
sudo systemctl start hdd-fan-control.service

# Stop automatic runs temporarily (for manual PWM testing)
sudo systemctl stop hdd-fan-control.timer

# Restart automatic runs
sudo systemctl start hdd-fan-control.timer
```

---

## Manual PWM Testing

While the timer is stopped you can test fan speeds manually:

```bash
# Find the current nct6798 hwmon path
for i in /sys/class/hwmon/hwmon*/name; do echo "$i: $(cat $i)"; done

# Example — assuming hwmon6 is nct6798:
HW=/sys/class/hwmon/hwmon6

# Enable manual PWM control
echo 1 | sudo tee ${HW}/pwm1_enable

# Set a specific PWM value (0–255)
echo 140 | sudo tee ${HW}/pwm1

# Monitor fan RPM
watch -n 1 cat ${HW}/fan1_input
```

---

## Logs

```bash
# Script log (one line per run)
sudo tail -f /var/log/hdd_fan_control.log

# systemd journal (stdout/stderr from each service run)
sudo journalctl -u hdd-fan-control.service -n 50
```

Log entries look like:

```
2025-07-10 14:32:01 - Temp: 43°C | Tier: Warm (≤43°C) | PWM: 90/255 (no change) | RPM: 847
2025-07-10 14:34:01 - Temp: 46°C | Tier: Hot (≤46°C) | PWM: 140/255 | RPM: 1320
```

### Log Rotation

Log rotation is handled by logrotate via `hdd-fan-control.logrotate`:

- Rotates **weekly**
- Keeps **4 weeks** of history
- Compressed with `gzip` (`delaycompress` keeps the most recent rotated file uncompressed for easy inspection)
- Uses `copytruncate` — safe since the script opens the log file fresh on each run

To test the logrotate config without waiting for the scheduled run:

```bash
sudo logrotate --debug /etc/logrotate.d/hdd-fan-control
# Force an actual rotation (even if not due yet):
sudo logrotate --force /etc/logrotate.d/hdd-fan-control
```
