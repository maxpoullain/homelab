# HDD Fan Control

Temperature-based fan control script for managing fan speed based on HDD temperatures.

## Installation

### 1. Enable PWM Control (if not already enabled)

First, you need to load the appropriate kernel module for PWM fan control. The most common module is `pwm-fan` or your motherboard's specific sensor module (e.g., `nct6775`, `it87`, `coretemp`).

```bash
# Check what sensor modules are available
sensors-detect

# Follow the prompts and load recommended modules
# Common modules:
sudo modprobe nct6775  # For Nuvoton chips
sudo modprobe it87     # For ITE chips
sudo modprobe w83627ehf # For Winbond chips

# Make the module load on boot
echo "nct6775" | sudo tee -a /etc/modules
# Or for it87:
# echo "it87" | sudo tee -a /etc/modules
```

### 2. Find Your PWM and Fan Paths

Locate the correct hwmon device and PWM/fan control paths:

```bash
# List all hwmon devices
ls -la /sys/class/hwmon/

# Find PWM controls
find /sys/class/hwmon -name "pwm*" -type f

# Find fan inputs (RPM sensors)
find /sys/class/hwmon -name "fan*_input" -type f

# Check the device name for each hwmon
for i in /sys/class/hwmon/hwmon*/name; do 
    echo "$i: $(cat $i)"
done

# Test which PWM controls which fan
# Example: Check current PWM value
cat /sys/class/hwmon/hwmon0/pwm2

# Example: Check current fan RPM
cat /sys/class/hwmon/hwmon0/fan2_input

# Test by setting PWM value
echo 1 | sudo tee /sys/class/hwmon/hwmon0/pwm2_enable  # Enable manual control
echo 150 | sudo tee /sys/class/hwmon/hwmon0/pwm2       # Set to medium speed
# Watch the RPM change to verify it's the correct fan
watch -n 1 cat /sys/class/hwmon/hwmon0/fan2_input
```

### 3. Configure the Script

Edit `hdd_fan_control.sh` and update the paths at the top of the file:

```bash
# Edit these paths based on your system
PWM_PATH="/sys/class/hwmon/hwmon6/pwm2"           # Your PWM control path
PWM_ENABLE_PATH="/sys/class/hwmon/hwmon6/pwm2_enable"
FAN_RPM_PATH="/sys/class/hwmon/hwmon6/fan2_input" # Your fan RPM sensor path

# Update the HDD devices you want to monitor
HDD_DEVICES=("/dev/sda" "/dev/sdb" "/dev/sdc" "/dev/sdd")
```

### 4. Install Required Tools

```bash
# Install smartmontools for reading HDD temperatures
sudo apt-get install smartmontools   # Debian/Ubuntu
# or
sudo yum install smartmontools        # CentOS/RHEL
# or
sudo pacman -S smartmontools          # Arch Linux
```

### 5. Test the Script

```bash
# Make the script executable
chmod +x hdd_fan_control.sh

# Test without making changes
./hdd_fan_control.sh -t

# Test with verbose output (requires root)
sudo ./hdd_fan_control.sh -v

# If everything looks good, run it normally
sudo ./hdd_fan_control.sh
```

## Configuration

- **PWM Path**: `/sys/class/hwmon/hwmon6/pwm2`
- **Fan RPM Path**: `/sys/class/hwmon/hwmon6/fan2_input`
- **Monitored HDDs**: `/dev/sda`, `/dev/sdb`, `/dev/sdc`, `/dev/sdd`

## Manual Fan Control

### Set Fan Speed Manually

To manually set the fan RPM, you need to write a PWM value (0-255) to the PWM control file:

```bash
# Enable manual PWM control
echo 1 | sudo tee /sys/class/hwmon/hwmon6/pwm2_enable

# Set PWM value (0-255)
echo <PWM_VALUE> | sudo tee /sys/class/hwmon/hwmon6/pwm2
```

### PWM to RPM Reference

Based on the script's temperature map (very quiet until 43°C, then aggressive ramp):

| PWM Value | Approx. RPM | Speed Level |
|-----------|-------------|-------------|
| 28        | ~329 RPM    | Very Quiet  |
| 35        | ~412 RPM    | Very Quiet  |
| 55        | ~647 RPM    | Very Quiet  |
| 80        | ~941 RPM    | Very Quiet  |
| 105       | ~1235 RPM   | Starting Ramp |
| 130       | ~1529 RPM   | Ramping Up  |
| 150       | ~1765 RPM   | Aggressive  |
| 170       | ~2000 RPM   | Aggressive  |
| 185       | ~2176 RPM   | Very Aggressive |
| 200       | ~2353 RPM   | Very Aggressive |
| 215       | ~2529 RPM   | Very Aggressive |
| 225       | ~2647 RPM   | Very Aggressive |
| 235       | ~2765 RPM   | Near Max    |
| 245       | ~2882 RPM   | Near Max    |
| 252       | ~2965 RPM   | Almost Max  |
| 255       | ~3000 RPM   | Maximum     |

### Examples

```bash
# Set fan to quiet mode (~412 RPM)
echo 1 | sudo tee /sys/class/hwmon/hwmon6/pwm2_enable
echo 35 | sudo tee /sys/class/hwmon/hwmon6/pwm2

# Set fan to medium speed (~1529 RPM)
echo 1 | sudo tee /sys/class/hwmon/hwmon6/pwm2_enable
echo 130 | sudo tee /sys/class/hwmon/hwmon6/pwm2

# Set fan to maximum speed (~3000 RPM)
echo 1 | sudo tee /sys/class/hwmon/hwmon6/pwm2_enable
echo 255 | sudo tee /sys/class/hwmon/hwmon6/pwm2

# Check current fan RPM
cat /sys/class/hwmon/hwmon6/fan2_input
```

## Using the Control Script

### Run the script manually

```bash
# Run with root privileges (applies temperature-based fan control)
sudo ./hdd_fan_control.sh

# Verbose mode - show detailed temperature and fan information
sudo ./hdd_fan_control.sh -v

# Test mode - show what would be done without making changes
sudo ./hdd_fan_control.sh -t

# Show help and temperature thresholds
./hdd_fan_control.sh -h
```

### Script Modes Explained

#### Normal Mode
```bash
sudo ./hdd_fan_control.sh
```
- Reads all HDD temperatures
- Determines the maximum temperature
- Sets the appropriate PWM value based on temperature thresholds
- Logs changes to `/var/log/hdd_fan_control.log`
- Silent operation (no console output unless there's an error)

#### Verbose Mode (`-v` or `--verbose`)
```bash
sudo ./hdd_fan_control.sh -v
```
Displays detailed information:
- Individual temperature for each HDD drive
- Maximum temperature across all drives
- Current PWM value and percentage
- Current fan RPM

Example output:
```
HDD Temperatures:
  /dev/sda: 42°C
  /dev/sdb: 38°C
  /dev/sdc: 45°C
  /dev/sdd: 40°C
Max Temperature: 45°C
PWM Value: 145/255 (56%)
Fan RPM: 1906
```

#### Test Mode (`-t` or `--test`)
```bash
./hdd_fan_control.sh -t
```
**Does NOT require root privileges** - safe to run without making changes:
- Shows all HDD temperatures
- Displays what the maximum temperature is
- Shows what PWM value **would** be set
- Does NOT actually change the fan speed
- Useful for checking HDD temps and verifying the script logic

Example output:
```
HDD Temperatures:
  /dev/sda: 42°C
  /dev/sdb: 38°C
  /dev/sdc: 45°C
  /dev/sdd: 40°C
Max Temperature: 45°C
Would set PWM to: 145
```

### Temperature Thresholds

The script uses the following temperature-based PWM mapping (very quiet until 43°C, then aggressive ramp):

- **≤30°C**: PWM 28 (~329 RPM) - Very quiet
- **≤35°C**: PWM 35 (~412 RPM) - Very quiet  
- **≤40°C**: PWM 55 (~647 RPM) - Very quiet
- **≤43°C**: PWM 80 (~941 RPM) - Very quiet
- **≤44°C**: PWM 105 (~1235 RPM) - Starting ramp
- **≤45°C**: PWM 130 (~1529 RPM) - Ramping up
- **≤46°C**: PWM 150 (~1765 RPM) - Aggressive
- **≤47°C**: PWM 170 (~2000 RPM) - Aggressive
- **≤48°C**: PWM 185 (~2176 RPM) - Very aggressive
- **≤49°C**: PWM 200 (~2353 RPM) - Very aggressive
- **≤50°C**: PWM 215 (~2529 RPM) - Very aggressive
- **≤51°C**: PWM 225 (~2647 RPM) - Very aggressive
- **≤52°C**: PWM 235 (~2765 RPM) - Near maximum
- **≤53°C**: PWM 245 (~2882 RPM) - Near maximum
- **≤54°C**: PWM 252 (~2965 RPM) - Almost maximum
- **>54°C**: PWM 255 (~3000 RPM) - Maximum cooling

## Setup as a Service

The service uses a systemd timer to run the fan control script every 2 minutes.

### Service Files

- `hdd-fan-control.service` - The service unit that runs the script
- `hdd-fan-control.timer` - Timer that triggers the service every 2 minutes (starts 1 minute after boot)

### Installation

```bash
# Copy files to systemd directory
sudo cp hdd_fan_control.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/hdd_fan_control.sh
sudo cp hdd-fan-control.service /etc/systemd/system/
sudo cp hdd-fan-control.timer /etc/systemd/system/

# Enable and start the timer
sudo systemctl daemon-reload
sudo systemctl enable hdd-fan-control.timer
sudo systemctl start hdd-fan-control.timer
```

### Service Management

```bash
# Check timer status
sudo systemctl status hdd-fan-control.timer

# Check when the timer will run next
sudo systemctl list-timers hdd-fan-control.timer

# View service logs
sudo journalctl -u hdd-fan-control.service -f
```

### Temporarily Disable Service for Testing

When you want to manually test PWM settings without the service interfering:

```bash
# Stop the timer (prevents automatic runs)
sudo systemctl stop hdd-fan-control.timer

# Verify it's stopped
sudo systemctl status hdd-fan-control.timer

# Now you can manually test PWM values
echo 1 | sudo tee /sys/class/hwmon/hwmon6/pwm2_enable
echo 145 | sudo tee /sys/class/hwmon/hwmon6/pwm2

# Monitor fan RPM while testing
watch -n 1 cat /sys/class/hwmon/hwmon6/fan2_input

# When done testing, restart the timer
sudo systemctl start hdd-fan-control.timer
```

### Permanently Disable Service

If you want to disable automatic fan control:

```bash
# Disable timer (won't start on boot)
sudo systemctl disable hdd-fan-control.timer

# Stop it immediately
sudo systemctl stop hdd-fan-control.timer
```

To re-enable later:

```bash
# Re-enable and start
sudo systemctl enable hdd-fan-control.timer
sudo systemctl start hdd-fan-control.timer
```

## Logs

The script logs its activity to `/var/log/hdd_fan_control.log`.

```bash
# View recent log entries
sudo tail -f /var/log/hdd_fan_control.log
```
