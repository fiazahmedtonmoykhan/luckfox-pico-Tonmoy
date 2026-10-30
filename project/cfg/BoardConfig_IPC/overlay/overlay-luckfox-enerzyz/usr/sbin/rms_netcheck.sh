#!/bin/sh

INTERFACE="eth0"
CONFIG_FILE="/etc/network/interfaces"
LOG_TAG="ip-check"

log()
{
    logger -t "$LOG_TAG" "$1"
}

# Check how the interface is configured (static/dhcp)
METHOD=$(awk '
    $1 == "iface" && $2 == "'"$INTERFACE"'" {
        print $4
        exit
    }
' "$CONFIG_FILE")

if [ -z "$METHOD" ]; then
    log "ERROR: Interface $INTERFACE not found in $CONFIG_FILE"
    exit 1
fi

if [ "$METHOD" = "dhcp" ]; then
    log "$INTERFACE is configured for DHCP. Skipping IP verification."
    exit 0
fi

if [ "$METHOD" != "static" ]; then
    log "ERROR: Unsupported configuration method '$METHOD' for $INTERFACE"
    exit 1
fi

# Read configured IP address and netmask
CONFIG_IP=$(awk '
    $1 == "iface" && $2 == "'"$INTERFACE"'" { found=1; next }
    found && $1 == "address" {
        print $2
        exit
    }
' "$CONFIG_FILE")

CONFIG_MASK=$(awk '
    $1 == "iface" && $2 == "'"$INTERFACE"'" { found=1; next }
    found && $1 == "netmask" {
        print $2
        exit
    }
' "$CONFIG_FILE")

if [ -z "$CONFIG_IP" ] || [ -z "$CONFIG_MASK" ]; then
    log "ERROR: Failed to read static IP configuration for $INTERFACE"
    exit 1
fi

# Get current IPv4 address (compatible with BusyBox and net-tools)
CURRENT_IP=$(ifconfig "$INTERFACE" 2>/dev/null | awk '
    /inet addr:/ {
        split($2, a, ":")
        print a[2]
        exit
    }
    /inet / {
        print $2
        exit
    }
')

if [ -z "$CURRENT_IP" ]; then
    log "No IPv4 address assigned to $INTERFACE."
else
    log "Current IP: $CURRENT_IP"
fi

if [ "$CURRENT_IP" = "$CONFIG_IP" ]; then
    log "$INTERFACE already configured correctly ($CURRENT_IP)"
    exit 0
fi

log "IP mismatch detected."
log "Configured IP : $CONFIG_IP"
log "Current IP    : ${CURRENT_IP:-None}"
log "Applying configured IP and netmask."

ifconfig "$INTERFACE" "$CONFIG_IP" netmask "$CONFIG_MASK" up

if [ $? -ne 0 ]; then
    log "ERROR: Failed to configure $INTERFACE"
    exit 1
fi

# Verify configuration
NEW_IP=$(ifconfig "$INTERFACE" 2>/dev/null | awk '
    /inet addr:/ {
        split($2, a, ":")
        print a[2]
        exit
    }
    /inet / {
        print $2
        exit
    }
')

if [ "$NEW_IP" = "$CONFIG_IP" ]; then
    log "Successfully configured $INTERFACE with IP $CONFIG_IP"
    exit 0
else
    log "ERROR: Verification failed. Current IP is ${NEW_IP:-None}"
    exit 1
fi