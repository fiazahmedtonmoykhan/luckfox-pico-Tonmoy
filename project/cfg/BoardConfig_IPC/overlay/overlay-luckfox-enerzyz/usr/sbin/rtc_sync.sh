#!/bin/sh

MIN_YEAR=2025
FLAG=/tmp/rtc_synced

# Already updated during this boot?
[ -f "$FLAG" ] && exit 0

YEAR=$(date +%Y)

[ "$YEAR" -lt "$MIN_YEAR" ] && exit 0

if hwclock -w; then
    logger -t rtc_sync "RTC updated successfully."
    touch "$FLAG"
else
    logger -t rtc_sync "Failed to update RTC."
fi