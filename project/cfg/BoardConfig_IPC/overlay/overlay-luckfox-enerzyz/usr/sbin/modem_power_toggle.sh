#!/bin/sh

# Configuration
GPIO_PIN=4
TARGET_IP="1.1.1.1"
GPIO_PATH="/sys/class/gpio/gpio$GPIO_PIN"
INTERVAL=60  # Check every 60 seconds

log() {
    local level="$1"
    local message="$2"
    logger -t "$LOG_TAG" "$level: $message"
}


# Initialize GPIO if not already exported
if [ ! -d "$GPIO_PATH" ]; then
    echo "$GPIO_PIN" > /sys/class/gpio/export
    echo out > "$GPIO_PATH/direction"
fi

log "INFO" "Starting Network Checker, targeting $TARGET_IP..."

# Ping once, wait up to 5 seconds for a response
if ping -c 1 -W 5 "$TARGET_IP" > /dev/null 2>&1; then
    # Network is UP
    log "INFO" "Network OK"
else
    # Network is DOWN - Trigger GPIO Toggle
    log "ERROR"  "Network Down! Toggling GPIO $GPIO_PIN..."

    echo 0 > "$GPIO_PATH/value"
    log "INFO" "MODEM POWERED OFF"
    
    sleep 5
    
    echo 1 > "$GPIO_PATH/value"
    log "INFO" "MODEM POWERED ON"
    
    # Wait a bit longer after a reset to allow hardware to reboot
    
    sleep 30 
fi
log "INFO" "EXITING FROM MODEM CHECKER"
