#!/bin/bash
# Interactive client for the TCP API server.
# Usage: ./apiClient.sh <server_ip> [port]

SERVER_IP="$1"
SERVER_PORT="${2:-4242}"
BYE_MESSAGE="Houston, we have a problem!"
TIMEOUT=5

if [[ -z "$SERVER_IP" ]]; then
    echo "Usage: $0 <server_ip> [port]"
    exit 1
fi

# Data the server asks for during the handshake
read -r -p "Your country [Ukraine]: " country
country="${country:-Ukraine}"
detected_ipv6="$(ip -6 addr show scope link 2>/dev/null | awk '/inet6/ { sub("/.*", "", $2); print $2; exit }')"
read -r -p "Your IPv6 address [${detected_ipv6:-::1}]: " ipv6
ipv6="${ipv6:-${detected_ipv6:-::1}}"

# Open a TCP connection on file descriptor 3 (bash built-in /dev/tcp)
if ! exec 3<>"/dev/tcp/$SERVER_IP/$SERVER_PORT"; then
    echo "Error: cannot connect to $SERVER_IP:$SERVER_PORT"
    exit 1
fi

send() {
    printf '%s\n' "$1" >&3
}

recv() {
    line=""
    IFS= read -r -t "$TIMEOUT" -u 3 line || return 1
    line="${line%$'\r'}"
}

disconnect() {
    exec 3>&-
    exit "${1:-0}"
}

# Any unexpected server message during the handshake closes the connection.
expect() {
    if ! recv || [[ "$line" != "$1" ]]; then
        echo "Handshake failed: expected '$1', got '${line:-nothing}'. Disconnecting."
        disconnect 1
    fi
}

# ---------- Handshake ----------
send "Hi&Hello!"
expect "Hello&Hi! Your Country?"
send "$country"
expect "Ok. Your ipv6 address?"
send "$ipv6"
expect "Ready."
echo "Connected to $SERVER_IP:$SERVER_PORT."
echo "Commands: GetAlbumBySong <song>, GetSongsOfPerformer <performer>, exit"

# ---------- Command loop ----------
while true; do
    if ! read -r -e -p "> " command; then
        command="exit"          # Ctrl+D
        echo
    fi
    [[ -z "$command" ]] && continue

    send "$command"
    if ! recv; then
        echo "Error: no response from server."
        disconnect 1
    fi

    if [[ "$line" =~ ^[0-9]+$ ]]; then
        count="$line"
        if (( count == 0 )); then
            echo "No data"
        else
            for (( i = 0; i < count; i++ )); do
                recv && echo "  $line"
            done
        fi
    elif [[ "$line" == ERROR* ]]; then
        echo "${line#ERROR }"
    elif [[ "$line" == "$BYE_MESSAGE" ]]; then
        echo "$line"
        disconnect 0
    else
        echo "Unexpected response from server: $line"
    fi
done
