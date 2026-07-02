#!/bin/sh
# godaddy-ddns.sh - one-shot updater
# Reads config, discovers the router's public IP, and PUTs it to the
# GoDaddy DNS API for each configured A record. Skips the API call when
# the IP has not changed since the last successful update (use --force
# to update regardless).

PKG_DIR="/var/packages/godaddy-ddns/target"
CONF="$PKG_DIR/etc/godaddy-ddns.conf"
VAR_DIR="$PKG_DIR/var"
LOG="$VAR_DIR/godaddy-ddns.log"
STATE="$VAR_DIR/last_ip"

mkdir -p "$VAR_DIR"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $*" >> "$LOG"
}

# Rotate the log at ~256 KB so it never grows unbounded on the router.
if [ -f "$LOG" ] && [ "$(wc -c < "$LOG")" -gt 262144 ]; then
    mv -f "$LOG" "$LOG.1"
fi

if [ ! -f "$CONF" ]; then
    log "ERROR: config file $CONF not found"
    exit 1
fi

. "$CONF"

if [ -z "$API_KEY" ] || [ -z "$API_SECRET" ] || [ -z "$DOMAIN" ]; then
    log "ERROR: API_KEY, API_SECRET and DOMAIN must be set in $CONF"
    exit 1
fi

RECORDS="${RECORDS:-@}"
TTL="${TTL:-600}"

# Discover the public IP, trying several services in case one is down.
IP=""
for url in "https://api.ipify.org" "https://checkip.amazonaws.com" "https://ifconfig.me/ip"; do
    IP=$(curl -fsS --max-time 10 "$url" 2>/dev/null | tr -d ' \t\r\n')
    if echo "$IP" | grep -Eq '^([0-9]{1,3}\.){3}[0-9]{1,3}$'; then
        break
    fi
    IP=""
done

if [ -z "$IP" ]; then
    log "ERROR: could not determine public IP from any provider"
    exit 1
fi

LAST=$(cat "$STATE" 2>/dev/null)
if [ "$IP" = "$LAST" ] && [ "$1" != "--force" ]; then
    # Quiet by default: unchanged IP leaves no log line. Set LOG_CHECKS=yes
    # in the config to log every check as a heartbeat.
    if [ "${LOG_CHECKS:-no}" = "yes" ]; then
        log "check: public IP $IP unchanged, nothing to do"
    fi
    exit 0
fi
log "check: public IP $IP (was ${LAST:-unknown}), updating GoDaddy"

ALL_OK=1
for rec in $RECORDS; do
    RESP="/tmp/godaddy-ddns-resp.$$"
    CODE=$(curl -sS --max-time 15 -o "$RESP" -w '%{http_code}' \
        -X PUT "https://api.godaddy.com/v1/domains/$DOMAIN/records/A/$rec" \
        -H "Authorization: sso-key $API_KEY:$API_SECRET" \
        -H "Content-Type: application/json" \
        -d "[{\"data\":\"$IP\",\"ttl\":$TTL}]" 2>>"$LOG")
    if [ "$CODE" = "200" ]; then
        log "OK: $rec.$DOMAIN -> $IP (ttl $TTL)"
    else
        ALL_OK=0
        log "FAILED: $rec.$DOMAIN (HTTP ${CODE:-none}): $(cat "$RESP" 2>/dev/null)"
    fi
    rm -f "$RESP"
done

if [ "$ALL_OK" = "1" ]; then
    echo "$IP" > "$STATE"
    exit 0
fi
exit 1
