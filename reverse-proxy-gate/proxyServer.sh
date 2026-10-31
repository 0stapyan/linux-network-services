#!/bin/bash
# Gatekeeper proxy in front of Apache.
# socat runs this script once per HTTP connection to port 80. The script reads
# the request, decides whether the client gets access and returns either
# index.html or error.html, fetched from Apache on the local-only port 10000.

BACKEND="http://127.0.0.1:10000"

# Read the request line and skip the headers (they end with an empty line)
IFS= read -r -t 5 request_line
request_line="${request_line%$'\r'}"
while IFS= read -r -t 5 header && [[ "${header%$'\r'}" != "" ]]; do :; done

# Access decision. It combines two values that change between requests:
#   A: PID of the parent socat process minus 5
#   B: first hex digit of the MD5 hash of the current process list
# If (A + B) is odd, access is granted. This is a placeholder rule:
# in a real system this is where an authentication or rate-limit check would go.
value_a=$(( SOCAT_PPID - 5 ))
hash=$(ps aux | md5sum | cut -c1)
value_b=$(( 16#$hash ))

if (( (value_a + value_b) % 2 == 1 )); then
    status="200 OK"
    page="index.html"
else
    status="403 Forbidden"
    page="error.html"
fi

echo "$(date '+%F %T') ${SOCAT_PEERADDR:-unknown} \"$request_line\" -> ${status%% *}" >&2

body="$(curl -s "$BACKEND/$page")"
if [[ -z "$body" ]]; then
    status="502 Bad Gateway"
    body="Backend is not available."
fi

# A valid HTTP response: status line, headers, empty line, body
printf 'HTTP/1.1 %s\r\n' "$status"
printf 'Content-Type: text/html; charset=utf-8\r\n'
printf 'Content-Length: %d\r\n' "$(printf '%s' "$body" | wc -c)"
printf 'Connection: close\r\n\r\n'
printf '%s' "$body"
