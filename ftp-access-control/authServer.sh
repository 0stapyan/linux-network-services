#!/bin/bash
# Authentication service for FTP access.
# socat runs this script once per connection to port 7777 and passes the
# client's IP address in SOCAT_PEERADDR. The client sends its key, and the
# script opens or closes FTP (port 21) for that IP with iptables.

CREDENTIALS_FILE="/etc/authServer/credentials.txt"
LOG_FILE="/var/log/authServer.log"
FTP_PORT=21
CLIENT_IP="$SOCAT_PEERADDR"

log() {
    echo "$(date '+%F %T') [$CLIENT_IP] $1" >> "$LOG_FILE"
}

# Deletes every existing FTP rule for this IP, so only the latest decision applies.
clear_rules() {
    while iptables -D INPUT -s "$CLIENT_IP" -p tcp --dport "$FTP_PORT" -j ACCEPT 2>/dev/null; do :; done
    while iptables -D INPUT -s "$CLIENT_IP" -p tcp --dport "$FTP_PORT" -j DROP 2>/dev/null; do :; done
}

# Inserts a rule at the top of the chain (-I), so it takes priority over
# the general "drop all FTP traffic" rule added at the end by install.sh (-A).
set_access() {
    clear_rules
    iptables -I INPUT -s "$CLIENT_IP" -p tcp --dport "$FTP_PORT" -j "$1"
}

if [[ -z "$CLIENT_IP" ]]; then
    echo "Error: cannot determine client IP address."
    exit 1
fi

if [[ ! -r "$CREDENTIALS_FILE" ]]; then
    echo "Error: authentication is temporarily unavailable."
    log "Credentials file $CREDENTIALS_FILE not found"
    exit 1
fi

echo "Enter authorization key for IP $CLIENT_IP:"
IFS= read -r -t 30 auth_key
auth_key="${auth_key%$'\r'}"

# Exact match of both fields: a partial or empty key never passes.
if awk -v ip="$CLIENT_IP" -v key="$auth_key" \
       '$1 == ip && $2 == key { found = 1 } END { exit !found }' "$CREDENTIALS_FILE"; then
    set_access ACCEPT
    echo "Authentication successful. FTP access granted for $CLIENT_IP."
    log "Authentication successful, FTP access granted"
else
    set_access DROP
    echo "Authentication failed. FTP access denied for $CLIENT_IP."
    log "Authentication failed, FTP access denied"
fi
