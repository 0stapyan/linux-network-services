#!/bin/bash
# Handles a single client connection.
# socat starts a new copy of this script for every incoming connection and
# connects its stdin/stdout to the TCP socket, so `read` receives data from
# the client and `echo` sends data back.

DB_FILE="/etc/apiServer/db.txt"
LOG_FILE="/var/log/apiServer.log"
BYE_MESSAGE="Houston, we have a problem!"
HANDSHAKE_TIMEOUT=10   # seconds to wait for each handshake message
IDLE_TIMEOUT=300       # seconds of inactivity before the connection is closed
CLIENT="${SOCAT_PEERADDR:-unknown}:${SOCAT_PEERPORT:-?}"
ARG_PATTERN="^[[:alnum:] '&.,!?()-]{1,100}$"

log() {
    echo "$(date '+%F %T') [$CLIENT] $1" >> "$LOG_FILE"
}

# Reads one line into $line with a timeout and strips a trailing CR,
# so clients that send CRLF line endings (telnet, netcat) also work.
read_line() {
    line=""
    IFS= read -r -t "$1" line || return 1
    line="${line%$'\r'}"
}

# Any deviation from the protocol during the handshake closes the connection.
drop() {
    log "Handshake failed: $1. Connection dropped."
    exit 1
}

trim() {
    local s="$1"
    s="${s#"${s%%[![:space:]]*}"}"
    s="${s%"${s##*[![:space:]]}"}"
    printf '%s' "$s"
}

# Prints the number of lines from stdin, then the lines themselves.
# An empty result is sent as a single "0".
respond() {
    local data
    data="$(cat)"
    if [[ -z "$data" ]]; then
        echo 0
    else
        wc -l <<< "$data"
        echo "$data"
    fi
}

# Exact, case-insensitive lookup in the database.
# $1 - column to match, $2 - column to return, $3 - value to look for
query() {
    awk -F';' -v col="$1" -v out="$2" -v q="$3" \
        'tolower($col) == tolower(q) { print $out }' "$DB_FILE"
}

# ---------- Handshake ----------
read_line "$HANDSHAKE_TIMEOUT" || drop "no greeting received"
[[ "$line" == "Hi&Hello!" ]] || drop "unexpected greeting '$line'"
echo "Hello&Hi! Your Country?"

read_line "$HANDSHAKE_TIMEOUT" || drop "no country received"
[[ "$line" =~ ^[[:alpha:]][[:alpha:]\ -]{1,49}$ ]] || drop "invalid country '$line'"
country="$line"
echo "Ok. Your ipv6 address?"

read_line "$HANDSHAKE_TIMEOUT" || drop "no IPv6 address received"
[[ "$line" =~ ^[0-9A-Fa-f:]{2,39}$ && "$line" == *:*:* ]] || drop "invalid IPv6 address '$line'"
ipv6="$line"
echo "Ready."
log "Handshake OK (country: $country, IPv6: $ipv6)"

# ---------- Commands ----------
while read_line "$IDLE_TIMEOUT"; do
    [[ -z "$line" ]] && continue

    command="${line%% *}"
    arg=""
    [[ "$line" == *" "* ]] && arg="$(trim "${line#* }")"
    log "Request: $line"

    case "$command" in
        exit|quit)
            break
            ;;
        GetAlbumBySong|GetSongsOfPerformer)
            if [[ ! "$arg" =~ $ARG_PATTERN ]]; then
                echo "ERROR Invalid argument. Usage: $command <name>"
                continue
            fi
            if [[ "$command" == "GetAlbumBySong" ]]; then
                query 1 3 "$arg" | respond      # song -> album
            else
                query 2 1 "$arg" | respond      # performer -> songs
            fi
            ;;
        *)
            echo "ERROR Unknown command '$command'. Available: GetAlbumBySong, GetSongsOfPerformer, exit"
            ;;
    esac
done

echo "$BYE_MESSAGE"
log "Connection closed"
