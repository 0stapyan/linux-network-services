#!/bin/bash
# Installs the ARP monitor as a systemd service triggered by a timer.
set -euo pipefail
cd "$(dirname "$0")"

sudo install -m 755 arp-monitor.sh /usr/local/bin/arp-monitor.sh
sudo install -m 644 arp-monitor.service arp-monitor.timer /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now arp-monitor.timer

echo "arp-monitor runs every 2 minutes. Logs: journalctl -u arp-monitor"
