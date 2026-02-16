#!/bin/sh
# Telegram notification sender
# Uses configuration from telegram.conf

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONF_DIR="/opt/etc/monitor-devices"

# Load Telegram configuration
if [ -f "${CONF_DIR}/telegram.conf" ]; then
    . "${CONF_DIR}/telegram.conf"
elif [ -f "${SCRIPT_DIR}/telegram.conf" ]; then
    . "${SCRIPT_DIR}/telegram.conf"
else
    echo "Error: telegram.conf not found"
    exit 1
fi

EVENT="$1"
DEVICE_NAME="$2"

# Check required parameters
if [ -z "$TELEGRAM_TOKEN" ] || [ -z "$TELEGRAM_CHAT_ID" ]; then
    echo "Error: TELEGRAM_TOKEN or TELEGRAM_CHAT_ID not set"
    exit 1
fi

# Log paths
LOG_DIR="/opt/var/log"
mkdir -p "$LOG_DIR"
LOG_FILE="${LOG_DIR}/telegram-notify.log"

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

# Rotate log before writing
rotate_log

# Log the call (only for important events)
echo "$(LOG_DATE): EVENT=$EVENT, DEVICE=$DEVICE_NAME" >> "$LOG_FILE"

# Define message based on event (using English for Telegram)
case "$EVENT" in
  connect|lease-added)
    MESSAGE="${DEVICE_NAME:-Device} connected to network"
    ;;
  disconnect|lease-deleted)
    MESSAGE="${DEVICE_NAME:-Device} disconnected from network"
    ;;
  test)
    MESSAGE="Test message from $(hostname)"
    ;;
  *)
    MESSAGE="${DEVICE_NAME:-Device} - ${EVENT}"
    ;;
esac

# Check internet connectivity before sending
check_internet() {
    # Ping Google DNS (1 packet, 3 sec timeout)
    if ! ping -c 1 -W 3 8.8.8.8 >/dev/null 2>&1; then
        echo "$(LOG_DATE): No internet connection, skipping" >> "$LOG_FILE"
        return 1
    fi
    return 0
}

# Send message to Telegram
send_message() {
    local msg="$1"
    
    # curl with 10 second timeout for compatibility
    # -s: silent mode
    # -X POST: POST method
    # --max-time 10: 10 second timeout
    # -w "\n%{http_code}": output HTTP code
    local response
    response=$(curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
        -d chat_id="${TELEGRAM_CHAT_ID}" \
        --data-urlencode text="${msg}" \
        --max-time 10 2>&1)
    
    local http_code=$(echo "$response" | tail -n1)
    
    # Check for errors
    if [ "$http_code" = "200" ]; then
        echo "$(LOG_DATE): Sent: $msg" >> "$LOG_FILE"
        return 0
    else
        echo "$(LOG_DATE): Error ($http_code): $response" >> "$LOG_FILE"
        return 1
    fi
}

# Main logic
main() {
    # Check internet
    if ! check_internet; then
        echo "No internet connection, skipping notification"
        exit 0
    fi
    
    # Send message
    if send_message "$MESSAGE"; then
        exit 0
    else
        exit 1
    fi
}

main
