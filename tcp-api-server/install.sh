#!/bin/bash
# Installs the TCP API server as a systemd service on Ubuntu.
set -euo pipefail
cd "$(dirname "$0")"

sudo apt-get update -y
sudo apt-get install -y socat

sudo install -m 755 apiServer.sh /usr/bin/apiServer.sh
sudo install -d /etc/apiServer
sudo install -m 644 db.txt /etc/apiServer/db.txt
sudo touch /var/log/apiServer.log
sudo install -m 644 apiServer.service /etc/systemd/system/apiServer.service

sudo systemctl daemon-reload
sudo systemctl enable --now apiServer.service

echo "apiServer is running on port 4242 and will start automatically on boot."
