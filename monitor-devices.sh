#!/bin/sh
# Monitor devices by MAC addresses
# Optimized version with configuration support

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONF_DIR="/opt/etc/monitor-devices"

# Load device configuration
if [ -f "${CONF_DIR}/devices.conf" ]; then
    . "${CONF_DIR}/devices.conf"
elif [ -f "${SCRIPT_DIR}/devices.conf" ]; then
    . "${SCRIPT_DIR}/devices.conf"
else
    echo "Error: devices.conf not found"
    exit 1
fi

# Flag directory for state tracking
FLAG_DIR="/tmp/monitor-devices"
mkdir -p "$FLAG_DIR"

# Log directory
LOG_DIR="/opt/var/log"
mkdir -p "$LOG_DIR"
LOG_FILE="${LOG_DIR}/monitor-devices.log"

# Date format for logs: dd-mm-yy HH:MM
LOG_DATE() {
    date +%d-%m-%y\ %H:%M
}

# Log rotation (builtin, no logrotate)
rotate_log() {
    if [ -f "$LOG_FILE" ]; then
        # Use wc -c instead of stat -c%s for BusyBox compatibility
        SIZE=$(wc -c < "$LOG_FILE" 2>/dev/null || echo 0)
        # Max size 10KB
        if [ "$SIZE" -gt 10240 ]; then
            tail -n 100 "$LOG_FILE" > "${LOG_FILE}.tmp" && mv "${LOG_FILE}.tmp" "$LOG_FILE"
        fi
    fi
}

# Logging
log_msg() {
    rotate_log
    echo "$(LOG_DATE): $1" >> "$LOG_FILE"
}

# Get device name by MAC address
# Uses DEVICES variable from config
get_device_name() {
    local mac="$1"
    local name=""
    
    # Check each MAC from the list
    for entry in $DEVICES; do
        mac_addr="${entry%%=*}"
        dev_name="${entry##*=}"
        if [ "$mac" = "$mac_addr" ]; then
            name="$dev_name"
            break
        fi
    done
    
    # If not found, return MAC
    if [ -z "$name" ]; then
        echo "$mac"
    else
        echo "$name"
    fi
}

# Check device status
check_device() {
    local mac="$1"
    local flag_file="${FLAG_DIR}/online-${mac}"
    
    # Check if MAC is in neighbour table (any active state except failed)
    # States: reachable, stale, delay, probe - all mean device is physically present
    # Only 'failed' means unreachable
    if ip neigh show nud all 2>/dev/null | grep -qi "$mac" && ! ip neigh show nud failed 2>/dev/null | grep -qi "$mac"; then
        # Device is online
        if [ ! -f "$flag_file" ]; then
            # Device appeared (was offline)
            local dev_name
            dev_name=$(get_device_name "$mac")
            log_msg "Device connected: $dev_name ($mac)"
            /opt/bin/notify-telegram.sh "connect" "$dev_name"
            touch "$flag_file"
        fi
    else
        # Device is offline
        if [ -f "$flag_file" ]; then
            # Device disappeared (was online)
            local dev_name
            dev_name=$(get_device_name "$mac")
            log_msg "Device disconnected: $dev_name ($mac)"
            /opt/bin/notify-telegram.sh "disconnect" "$dev_name"
            rm "$flag_file"
        fi
    fi
}

# Main monitoring function
main() {
    # Get neighbour table (all active states except failed)
    local neigh
    neigh=$(ip neigh show nud all 2>/dev/null | grep -v 'nud failed')
    
    # Check each device from config
    for entry in $DEVICES; do
        local mac="${entry%%=*}"
        check_device "$mac"
    done
}

# Run
main
