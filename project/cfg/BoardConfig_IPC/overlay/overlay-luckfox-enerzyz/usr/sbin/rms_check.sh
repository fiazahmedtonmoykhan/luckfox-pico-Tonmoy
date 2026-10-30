#!/bin/sh

APP="/etc/init.d/S99rmsstart"
APP_NAME="enerzyz_rms"
LOG_TAG="enerzyz_rms-watchdog"

log()
{
    logger -t "$LOG_TAG" "$1"
}

#cleanup mnt/sdcard di
log "INFO: Cleaning up /mnt/sdcard/ core dumps"
rm -rf /mnt/sdcard/core*

if [ ! -x "$APP" ]; then
    log "ERROR: Application not found or not executable: $APP"
    exit 1
fi

# Check if application is already running
if pidof "$APP_NAME" >/dev/null 2>&1; then
    log "$APP_NAME is already running."
    exit 0
fi

log "$APP_NAME is not running. Starting application..."

"$APP" start

sleep 1

# Verify application started successfully
if pidof "$APP_NAME" >/dev/null 2>&1; then
    log "$APP_NAME started successfully."
    exit 0
else
    log "ERROR: Failed to start $APP_NAME."
    exit 1
fi