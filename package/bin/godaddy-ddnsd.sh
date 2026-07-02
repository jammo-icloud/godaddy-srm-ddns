#!/bin/sh
# godaddy-ddnsd.sh - daemon loop
# Runs the one-shot updater every CHECK_INTERVAL seconds. Started and
# stopped by the package's start-stop-status script; avoids touching
# the router's crond entirely.

PKG_DIR="/var/packages/godaddy-ddns/target"
CONF="$PKG_DIR/etc/godaddy-ddns.conf"

while true; do
    "$PKG_DIR/bin/godaddy-ddns.sh"
    # Re-read the interval each cycle so config edits apply without a restart.
    INTERVAL=300
    if [ -f "$CONF" ]; then
        . "$CONF"
        INTERVAL="${CHECK_INTERVAL:-300}"
    fi
    sleep "$INTERVAL"
done
