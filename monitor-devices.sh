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

# Delay before sending disconnect notification (in seconds)
OFFLINE_DELAY=15

# Log directory
LOG_DIR="/opt/var/log"
mkdir -p "$LOG_DIR"
LOG_FILE="${LOG_DIR}/monitor-devices.log"

# Main function logging toggle (true/false)
ENABLE_MAIN_LOGGING=false

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

# Get current timestamp in seconds
get_timestamp() {
    date +%s
}

# Check device status and return online/offline
check_device() {
    local mac="$1"
    local flag_file="${FLAG_DIR}/online-${mac}"
    local offline_start_file="${FLAG_DIR}/offline-start-${mac}"
    local dev_name
    dev_name=$(get_device_name "$mac")
    
    # Get only IPv4 neighbour entries first (lines starting with digit)
    # Then search for MAC in IPv4 entries only
    if ip neigh show 2>/dev/null | grep -E "^[0-9]" | grep -qi "$mac"; then
        # Device is online
        # Remove offline start file if exists (device returned)
        if [ -f "$offline_start_file" ]; then
            rm -f "$offline_start_file"
            log_msg "Device returned: $dev_name ($mac)"
        fi
        
        if [ ! -f "$flag_file" ]; then
            # Device appeared (was offline)
            log_msg "Device connected: $dev_name ($mac)"
            /opt/bin/notify-telegram.sh "connect" "$dev_name"
            touch "$flag_file"
        fi
        echo "online"
    else
        # Device is offline
        if [ -f "$flag_file" ]; then
            # Device disappeared (was online)
            # Check if we already started offline timer
            if [ ! -f "$offline_start_file" ]; then
                # First time offline - start timer
                echo "$(get_timestamp)" > "$offline_start_file"
                log_msg "Device lost, waiting ${OFFLINE_DELAY}s: $dev_name ($mac)"
            else
                # Check if delay has passed
                local start_time
                start_time=$(cat "$offline_start_file" 2>/dev/null)
                local current_time
                current_time=$(get_timestamp)
                local elapsed=$((current_time - start_time))
                
                if [ "$elapsed" -ge "$OFFLINE_DELAY" ]; then
                    # Delay passed - send disconnect notification
                    log_msg "Device disconnected: $dev_name ($mac)"
                    /opt/bin/notify-telegram.sh "disconnect" "$dev_name"
                    rm -f "$flag_file"
                    rm -f "$offline_start_file"
                else
                    # Still waiting
                    log_msg "Device still offline, ${OFFLINE_DELAY}s left: $dev_name ($mac)"
                fi
            fi
        fi
        echo "offline"
    fi
}

# Main monitoring function
main() {
    # Get all neighbour entries
    local neigh
    neigh=$(ip neigh show 2>/dev/null)
    
    # Log header
    if [ "$ENABLE_MAIN_LOGGING" = true ]; then
        log_msg "Device Status:"
    fi
    
    # Check each device from config and log status
    for entry in $DEVICES; do
        local mac="${entry%%=*}"
        local status
        status=$(check_device "$mac")
        local dev_name
        dev_name=$(get_device_name "$mac")
        
        # Log each device on separate line
        if [ "$ENABLE_MAIN_LOGGING" = true ]; then
            if [ "$status" = "online" ]; then
                log_msg "${dev_name} - ONLINE"
            else
                log_msg "${dev_name} - OFFLINE"
            fi
        fi
    done
    
    # Log separator
    if [ "$ENABLE_MAIN_LOGGING" = true ]; then
        log_msg "======================================"
    fi
}

# Run
main
