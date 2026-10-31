#!/bin/bash
# Prints the current time and the ARP cache (IP and MAC of each neighbour) on one line:
# Oct 31 10:00 : 10.0.0.1 52:54:00:12:34:56 10.0.0.7 52:54:00:ab:cd:ef
neighbours=$(ip neigh show | awk '{ for (i = 1; i < NF; i++) if ($i == "lladdr") print $1, $(i + 1) }' | paste -sd ' ' -)
echo "$(date '+%b %d %H:%M') : ${neighbours:-(empty)}"
