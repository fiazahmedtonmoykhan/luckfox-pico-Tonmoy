#!/bin/bash

log() {
    logger -t "DNS Updater" "$1"
}

# Check if the file already contains 1.1.1.1 or 8.8.8.8
if grep -qE "nameserver[[:space:]]+(1\.1\.1\.1|8\.8\.8\.8)" /etc/resolv.conf; then
    log "Nameserver 1.1.1.1 or 8.8.8.8 is already set. No update needed."
else
    log "Adding nameserver 1.1.1.1"
    echo "nameserver 1.1.1.1" > /etc/resolv.conf
fi