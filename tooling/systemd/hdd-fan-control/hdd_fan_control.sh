#!/bin/bash

# HDD Temperature-based Fan Control Script
# Controls fan speed via PWM based on maximum HDD temperature
# Dynamically resolves the hwmon path for the nct6798 chip

# === CONFIGURATION ===
HWMON_CHIP_NAME="nct6798"
PWM_CHANNEL="pwm1"
LOG_FILE="/var/log/hdd_fan_control.log"
STATE_FILE="/run/hdd_fan_control_state"
HYSTERESIS=1  # °C — only step down a tier if temp dropped this many degrees below threshold

# HDD devices to monitor (used as fallback if no drivetemp hwmon entries found)
HDD_DEVICES=("/dev/sda" "/dev/sdb" "/dev/sdc" "/dev/sdd")

# Temperature curve: "THRESHOLD_CELSIUS PWM_VALUE LABEL"
# Evaluated in order — first matching threshold wins
# Final entry acts as catch-all (use 999 as threshold)
TEMP_CURVE=(
    "35  30  Idle"
    "40  60  Cool"
    "43  100  Warm"
    "46  145 Hot"
    "50  190 VeryHot"
    "54  230 Critical"
    "999 255 Max"
)

# === GLOBALS (resolved at runtime) ===
HWMON_PATH=""
PWM_PATH=""
PWM_ENABLE_PATH=""
FAN_RPM_PATH=""

# ===========================================================================
# Logging
# ===========================================================================

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# ===========================================================================
# Module + hwmon path resolution
# ===========================================================================

ensure_module() {
    if ! lsmod | grep -q "^nct6775"; then
        modprobe nct6775 2>/dev/null
        sleep 1
    fi
}

find_hwmon_path() {
    local name_file hwmon_dir found=""

    ensure_module

    for name_file in /sys/class/hwmon/hwmon*/name; do
        if [[ -r "$name_file" ]] && [[ "$(cat "$name_file" 2>/dev/null)" == "$HWMON_CHIP_NAME" ]]; then
            found="${name_file%/name}"
            break
        fi
    done

    if [[ -z "$found" ]]; then
        log_message "ERROR: hwmon device '$HWMON_CHIP_NAME' not found under /sys/class/hwmon/"
        return 1
    fi

    HWMON_PATH="$found"
    PWM_PATH="${HWMON_PATH}/${PWM_CHANNEL}"
    PWM_ENABLE_PATH="${HWMON_PATH}/${PWM_CHANNEL}_enable"
    FAN_RPM_PATH="${HWMON_PATH}/fan1_input"
    return 0
}

# ===========================================================================
# Temperature reading
# ===========================================================================

# Read temperatures from drivetemp hwmon entries (preferred)
# Values are in millidegrees Celsius — divide by 1000
get_temps_from_drivetemp() {
    local temps=()
    local name_file temp_file temp_raw

    for name_file in /sys/class/hwmon/hwmon*/name; do
        if [[ -r "$name_file" ]] && [[ "$(cat "$name_file" 2>/dev/null)" == "drivetemp" ]]; then
            temp_file="${name_file%/name}/temp1_input"
            if [[ -r "$temp_file" ]]; then
                temp_raw=$(cat "$temp_file" 2>/dev/null)
                if [[ -n "$temp_raw" && "$temp_raw" -gt 0 ]]; then
                    temps+=("$(( temp_raw / 1000 ))")
                fi
            fi
        fi
    done

    echo "${temps[@]}"
}

# Fallback: read temperature via smartctl for a single device
get_hdd_temp_smartctl() {
    local device=$1
    local temp

    temp=$(smartctl -A "$device" 2>/dev/null | awk '/Temperature_Celsius/ {print $10}' | head -1)
    if [[ -z "$temp" ]]; then
        temp=$(smartctl -A "$device" 2>/dev/null | awk '/Airflow_Temperature/ {print $10}' | head -1)
    fi
    if [[ -z "$temp" ]]; then
        temp=$(smartctl -A "$device" 2>/dev/null | awk '/Current Drive Temperature/ {print $4}' | head -1)
    fi

    echo "${temp:-0}"
}

# Returns the maximum temperature across all HDDs
# Prefers drivetemp hwmon entries; falls back to smartctl
get_max_hdd_temp() {
    local max_temp=0
    local temps temp

    # Try drivetemp first
    read -ra temps <<< "$(get_temps_from_drivetemp)"

    if [[ ${#temps[@]} -gt 0 ]]; then
        for temp in "${temps[@]}"; do
            if (( temp > max_temp )); then
                max_temp=$temp
            fi
        done
        echo "$max_temp"
        return
    fi

    # Fallback: smartctl per device
    for device in "${HDD_DEVICES[@]}"; do
        if [[ -e "$device" ]]; then
            temp=$(get_hdd_temp_smartctl "$device")
            if (( temp > max_temp )); then
                max_temp=$temp
            fi
        fi
    done

    echo "$max_temp"
}

# ===========================================================================
# Temperature curve + hysteresis
# ===========================================================================

# Returns "THRESHOLD PWM LABEL" for a given temperature
get_curve_entry_for_temp() {
    local temp=$1
    local entry threshold pwm label

    for entry in "${TEMP_CURVE[@]}"; do
        read -r threshold pwm label <<< "$entry"
        if (( temp <= threshold )); then
            echo "$threshold $pwm $label"
            return
        fi
    done

    # Should never reach here due to 999 catch-all, but be safe
    echo "999 255 Max"
}

# Returns the saved threshold from the state file (or empty string)
load_saved_threshold() {
    if [[ -r "$STATE_FILE" ]]; then
        cat "$STATE_FILE" 2>/dev/null
    fi
}

save_threshold() {
    echo "$1" > "$STATE_FILE" 2>/dev/null
}

# Apply hysteresis: if temperature would cause a step DOWN, only allow it
# if temp has dropped at least HYSTERESIS degrees below the current tier threshold.
get_pwm_with_hysteresis() {
    local current_temp=$1
    read -r target_threshold target_pwm target_label <<< "$(get_curve_entry_for_temp "$current_temp")"

    local saved_threshold
    saved_threshold=$(load_saved_threshold)

    if [[ -n "$saved_threshold" ]] && (( target_threshold < saved_threshold )); then
        # We're considering stepping down — apply hysteresis
        local hysteresis_floor=$(( saved_threshold - HYSTERESIS ))
        if (( current_temp > hysteresis_floor )); then
            # Not cold enough yet — stay at current (saved) tier
            read -r target_threshold target_pwm target_label <<< "$(get_curve_entry_for_temp "$saved_threshold")"
        fi
    fi

    save_threshold "$target_threshold"
    echo "$target_threshold $target_pwm $target_label"
}

# ===========================================================================
# PWM control
# ===========================================================================

set_pwm() {
    local pwm_value=$1

    if [[ ! -w "$PWM_ENABLE_PATH" ]]; then
        log_message "ERROR: Cannot write to PWM enable path: $PWM_ENABLE_PATH"
        return 1
    fi

    echo 1 > "$PWM_ENABLE_PATH" 2>/dev/null

    if [[ -w "$PWM_PATH" ]]; then
        echo "$pwm_value" > "$PWM_PATH" 2>/dev/null
        return 0
    else
        log_message "ERROR: Cannot write to PWM path: $PWM_PATH"
        return 1
    fi
}

get_current_pwm() {
    if [[ -r "$PWM_PATH" ]]; then
        cat "$PWM_PATH" 2>/dev/null || echo "0"
    else
        echo "0"
    fi
}

get_fan_rpm() {
    if [[ -r "$FAN_RPM_PATH" ]]; then
        cat "$FAN_RPM_PATH" 2>/dev/null || echo "0"
    else
        echo "0"
    fi
}

# ===========================================================================
# Display helpers
# ===========================================================================

show_hdd_temps() {
    local name_file temp_file temp_raw temp hwmon_dir idx=1
    local found_drivetemp=false

    echo "HDD Temperatures (drivetemp):"
    for name_file in /sys/class/hwmon/hwmon*/name; do
        if [[ -r "$name_file" ]] && [[ "$(cat "$name_file" 2>/dev/null)" == "drivetemp" ]]; then
            found_drivetemp=true
            hwmon_dir="${name_file%/name}"
            temp_file="${hwmon_dir}/temp1_input"
            if [[ -r "$temp_file" ]]; then
                temp_raw=$(cat "$temp_file" 2>/dev/null)
                temp=$(( temp_raw / 1000 ))
                echo "  Drive ${idx} (${hwmon_dir}): ${temp}°C"
            fi
            (( idx++ ))
        fi
    done

    if ! $found_drivetemp; then
        echo "  (no drivetemp entries found — falling back to smartctl)"
        for device in "${HDD_DEVICES[@]}"; do
            if [[ -e "$device" ]]; then
                temp=$(get_hdd_temp_smartctl "$device")
                echo "  $device: ${temp}°C"
            else
                echo "  $device: not found"
            fi
        done
    fi
}

# ===========================================================================
# Main modes
# ===========================================================================

cmd_status() {
    find_hwmon_path || exit 1

    local max_temp
    max_temp=$(get_max_hdd_temp)

    read -r threshold pwm label <<< "$(get_curve_entry_for_temp "$max_temp")"
    local pct=$(( pwm * 100 / 255 ))
    local current_pwm current_rpm
    current_pwm=$(get_current_pwm)
    current_rpm=$(get_fan_rpm)

    echo "========================================"
    echo " HDD Fan Control — Status"
    echo "========================================"
    show_hdd_temps
    echo ""
    echo "  Chip hwmon path : $HWMON_PATH"
    echo "  Max HDD temp    : ${max_temp}°C"
    echo "  Target tier     : $label (≤${threshold}°C)"
    echo "  Target PWM      : $pwm / 255 (${pct}%)"
    echo "  Current PWM     : $current_pwm / 255"
    echo "  Fan RPM         : $current_rpm RPM"
    echo "========================================"
}

cmd_test() {
    find_hwmon_path || exit 1

    local max_temp
    max_temp=$(get_max_hdd_temp)
    read -r threshold pwm label <<< "$(get_curve_entry_for_temp "$max_temp")"

    show_hdd_temps
    echo ""
    echo "Resolved hwmon path : $HWMON_PATH"
    echo "Max Temperature     : ${max_temp}°C"
    echo "Would set PWM to    : $pwm (tier: $label, threshold: ≤${threshold}°C)"
}

cmd_help() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -s, --status     Show current temperatures, fan speed and resolved hwmon path"
    echo "  -v, --verbose    Run normally but also print detailed status to stdout"
    echo "  -t, --test       Test mode — show what would be done, no changes made"
    echo "  -h, --help       Show this help message"
    echo ""
    echo "Temperature curve (hysteresis: ${HYSTERESIS}°C step-down guard):"
    echo ""
    printf "  %-12s %-8s %-10s %s\n" "Max Temp" "PWM" "% Speed" "Label"
    printf "  %-12s %-8s %-10s %s\n" "--------" "---" "-------" "-----"
    for entry in "${TEMP_CURVE[@]}"; do
        read -r thr pwm lbl <<< "$entry"
        local pct=$(( pwm * 100 / 255 ))
        local thr_disp
        if (( thr >= 999 )); then
            thr_disp=">54°C"
        else
            thr_disp="≤${thr}°C"
        fi
        printf "  %-12s %-8s %-10s %s\n" "$thr_disp" "$pwm" "${pct}%" "$lbl"
    done
    echo ""
    echo "Chip      : $HWMON_CHIP_NAME (module: nct6775)"
    echo "PWM       : $PWM_CHANNEL"
    echo "Log file  : $LOG_FILE"
    echo "State file: $STATE_FILE"
}

cmd_main() {
    local verbose=${1:-false}

    # Must be root
    if [[ $EUID -ne 0 ]]; then
        echo "ERROR: This script must be run as root" >&2
        exit 1
    fi

    find_hwmon_path || exit 1

    local max_temp
    max_temp=$(get_max_hdd_temp)

    if [[ "$max_temp" -eq 0 ]]; then
        log_message "WARNING: No HDD temperatures detected — setting fan to safe medium speed (PWM 120)"
        set_pwm 120
        exit 1
    fi

    read -r threshold pwm label <<< "$(get_pwm_with_hysteresis "$max_temp")"

    local current_pwm
    current_pwm=$(get_current_pwm)

    if [[ "$current_pwm" -ne "$pwm" ]]; then
        if set_pwm "$pwm"; then
            sleep 2
            local new_rpm
            new_rpm=$(get_fan_rpm)
            log_message "Temp: ${max_temp}°C | Tier: ${label} (≤${threshold}°C) | PWM: ${pwm}/255 | RPM: ${new_rpm}"
        else
            log_message "ERROR: Failed to set PWM to $pwm"
            exit 1
        fi
    else
        log_message "Temp: ${max_temp}°C | Tier: ${label} (≤${threshold}°C) | PWM: ${pwm}/255 (no change) | RPM: $(get_fan_rpm)"
    fi

    if [[ "$verbose" == "true" ]]; then
        show_hdd_temps
        echo ""
        echo "Resolved hwmon path : $HWMON_PATH"
        echo "Max Temperature     : ${max_temp}°C"
        echo "Tier                : $label (≤${threshold}°C)"
        echo "PWM Value           : ${pwm}/255 ($(( pwm * 100 / 255 ))%)"
        echo "Fan RPM             : $(get_fan_rpm) RPM"
    fi
}

# ===========================================================================
# Entry point
# ===========================================================================

case "${1:-}" in
    -s|--status)
        cmd_status
        ;;
    -t|--test)
        cmd_test
        ;;
    -v|--verbose)
        cmd_main "true"
        ;;
    -h|--help)
        cmd_help
        ;;
    "")
        cmd_main "false"
        ;;
    *)
        echo "Unknown option: $1" >&2
        echo "Run '$0 --help' for usage." >&2
        exit 1
        ;;
esac
