#!/bin/bash

# HDD Temperature-based Fan Control Script
# Controls hwmon/pwm2 based on maximum HDD temperature

# Configuration - adjust these paths based on your system
PWM_PATH="/sys/class/hwmon/hwmon6/pwm2"
PWM_ENABLE_PATH="/sys/class/hwmon/hwmon6/pwm2_enable"
FAN_RPM_PATH="/sys/class/hwmon/hwmon6/fan2_input"
LOG_FILE="/var/log/hdd_fan_control.log"

# HDD devices to monitor
HDD_DEVICES=("/dev/sda" "/dev/sdb" "/dev/sdc" "/dev/sdd")

# Temperature thresholds and corresponding PWM values
# Very quiet below 43°C, then aggressive ramp to 55°C
declare -A TEMP_MAP
TEMP_MAP[30]=28    # ≤30°C: ~329 RPM (very quiet)
TEMP_MAP[35]=35    # ≤35°C: ~412 RPM (very quiet)  
TEMP_MAP[40]=55    # ≤40°C: ~647 RPM (very quiet)
TEMP_MAP[43]=80    # ≤43°C: ~941 RPM (very quiet)
TEMP_MAP[44]=105   # ≤44°C: ~1235 RPM (starting ramp)
TEMP_MAP[45]=130   # ≤45°C: ~1529 RPM (ramping up)
TEMP_MAP[46]=150   # ≤46°C: ~1765 RPM (aggressive)
TEMP_MAP[47]=170   # ≤47°C: ~2000 RPM (aggressive)
TEMP_MAP[48]=185   # ≤48°C: ~2176 RPM (very aggressive)
TEMP_MAP[49]=200   # ≤49°C: ~2353 RPM (very aggressive)
TEMP_MAP[50]=215   # ≤50°C: ~2529 RPM (very aggressive)
TEMP_MAP[51]=225   # ≤51°C: ~2647 RPM (very aggressive)
TEMP_MAP[52]=235   # ≤52°C: ~2765 RPM (near maximum)
TEMP_MAP[53]=245   # ≤53°C: ~2882 RPM (near maximum)
TEMP_MAP[54]=252   # ≤54°C: ~2965 RPM (almost maximum)
TEMP_MAP[55]=255   # >54°C: ~3000 RPM (maximum cooling)

# Function to log messages
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Function to get HDD temperature via SMART
get_hdd_temp() {
    local device=$1
    local temp
    
    # Try different SMART temperature attributes
    temp=$(smartctl -A "$device" 2>/dev/null | awk '/Temperature_Celsius/ {print $10}' | head -1)
    if [[ -z "$temp" ]]; then
        temp=$(smartctl -A "$device" 2>/dev/null | awk '/Airflow_Temperature/ {print $10}' | head -1)
    fi
    if [[ -z "$temp" ]]; then
        temp=$(smartctl -A "$device" 2>/dev/null | awk '/Current Drive Temperature/ {print $4}' | head -1)
    fi
    
    # Return temperature or 0 if not found
    echo "${temp:-0}"
}

# Function to get maximum HDD temperature
get_max_hdd_temp() {
    local max_temp=0
    local temp
    
    for device in "${HDD_DEVICES[@]}"; do
        if [[ -e "$device" ]]; then
            temp=$(get_hdd_temp "$device")
            if [[ "$temp" -gt "$max_temp" ]]; then
                max_temp=$temp
            fi
        fi
    done
    
    echo "$max_temp"
}

# Function to set PWM value
set_pwm() {
    local pwm_value=$1
    
    # Enable PWM control if not already enabled
    if [[ ! -w "$PWM_ENABLE_PATH" ]]; then
        log_message "ERROR: Cannot write to PWM enable path: $PWM_ENABLE_PATH"
        return 1
    fi
    
    echo 1 > "$PWM_ENABLE_PATH" 2>/dev/null
    
    # Set PWM value
    if [[ -w "$PWM_PATH" ]]; then
        echo "$pwm_value" > "$PWM_PATH"
        return 0
    else
        log_message "ERROR: Cannot write to PWM path: $PWM_PATH"
        return 1
    fi
}

# Function to get current fan RPM
get_fan_rpm() {
    if [[ -r "$FAN_RPM_PATH" ]]; then
        cat "$FAN_RPM_PATH" 2>/dev/null || echo "0"
    else
        echo "0"
    fi
}

# Function to determine PWM value based on temperature
get_pwm_for_temp() {
    local temp=$1
    local pwm_value=255  # Default to maximum
    
    # Find appropriate PWM value based on temperature thresholds
    for threshold in $(echo "${!TEMP_MAP[@]}" | tr ' ' '\n' | sort -n); do
        if [[ "$temp" -le "$threshold" ]]; then
            pwm_value=${TEMP_MAP[$threshold]}
            break
        fi
    done
    
    echo "$pwm_value"
}

# Function to display HDD temperatures
show_hdd_temps() {
    echo "HDD Temperatures:"
    for device in "${HDD_DEVICES[@]}"; do
        if [[ -e "$device" ]]; then
            temp=$(get_hdd_temp "$device")
            echo "  $device: ${temp}°C"
        else
            echo "  $device: Not found"
        fi
    done
}

# Main control function
main() {
    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        echo "This script must be run as root"
        exit 1
    fi
    
    # Get maximum HDD temperature
    max_temp=$(get_max_hdd_temp)
    
    if [[ "$max_temp" -eq 0 ]]; then
        log_message "WARNING: No HDD temperatures detected, setting fan to medium speed"
        set_pwm 120
        exit 1
    fi
    
    # Determine required PWM value
    required_pwm=$(get_pwm_for_temp "$max_temp")
    
    # Get current PWM and fan RPM
    current_pwm=$(cat "$PWM_PATH" 2>/dev/null || echo "0")
    current_rpm=$(get_fan_rpm)
    
    # Only change PWM if different (avoid unnecessary writes)
    if [[ "$current_pwm" -ne "$required_pwm" ]]; then
        if set_pwm "$required_pwm"; then
            # Wait a moment for fan to respond
            sleep 2
            new_rpm=$(get_fan_rpm)
            log_message "Temp: ${max_temp}°C → PWM: $required_pwm → RPM: $new_rpm"
        else
            log_message "ERROR: Failed to set PWM to $required_pwm"
            exit 1
        fi
    fi
    
    # If verbose mode requested
    if [[ "$1" == "-v" || "$1" == "--verbose" ]]; then
        show_hdd_temps
        echo "Max Temperature: ${max_temp}°C"
        echo "PWM Value: $required_pwm/255 ($(( required_pwm * 100 / 255 ))%)"
        echo "Fan RPM: $(get_fan_rpm)"
    fi
}

# Handle command line arguments
case "${1:-}" in
    -h|--help)
        echo "Usage: $0 [OPTIONS]"
        echo "Options:"
        echo "  -v, --verbose    Show detailed temperature and fan information"
        echo "  -t, --test       Test mode - show what would be done"
        echo "  -h, --help       Show this help message"
        echo ""
        echo "Temperature thresholds (very quiet <43°C, then aggressive ramp to 55°C):"
        for threshold in $(echo "${!TEMP_MAP[@]}" | tr ' ' '\n' | sort -n); do
            pwm=${TEMP_MAP[$threshold]}
            rpm_estimate=""
            case $pwm in
                28) rpm_estimate="~329 RPM" ;;
                35) rpm_estimate="~412 RPM" ;;
                55) rpm_estimate="~647 RPM" ;;
                80) rpm_estimate="~941 RPM" ;;
                105) rpm_estimate="~1235 RPM" ;;
                130) rpm_estimate="~1529 RPM" ;;
                150) rpm_estimate="~1765 RPM" ;;
                170) rpm_estimate="~2000 RPM" ;;
                185) rpm_estimate="~2176 RPM" ;;
                200) rpm_estimate="~2353 RPM" ;;
                215) rpm_estimate="~2529 RPM" ;;
                225) rpm_estimate="~2647 RPM" ;;
                235) rpm_estimate="~2765 RPM" ;;
                245) rpm_estimate="~2882 RPM" ;;
                252) rpm_estimate="~2965 RPM" ;;
                255) rpm_estimate="~3000 RPM" ;;
            esac
            echo "  ≤${threshold}°C: PWM $pwm $rpm_estimate"
        done
        exit 0
        ;;
    -t|--test)
        max_temp=$(get_max_hdd_temp)
        required_pwm=$(get_pwm_for_temp "$max_temp")
        show_hdd_temps
        echo "Max Temperature: ${max_temp}°C"
        echo "Would set PWM to: $required_pwm"
        exit 0
        ;;
    *)
        main "$@"
        ;;
esac