#!/bin/bash
# Moves Apache to a local-only port 10000 and puts a gatekeeper proxy on port 80.
set -euo pipefail
cd "$(dirname "$0")"

add_rule() {
    sudo iptables -C "$@" 2>/dev/null || sudo iptables -A "$@"
}

# ---------- Packages ----------
sudo apt-get update -y
sudo apt-get install -y apache2 socat curl iptables

# ---------- Apache on port 10000 ----------
sudo sed -i 's/^Listen 80$/Listen 10000/' /etc/apache2/ports.conf
sudo sed -i 's/<VirtualHost \*:80>/<VirtualHost *:10000>/' /etc/apache2/sites-available/000-default.conf
sudo install -m 644 index.html error.html /var/www/html/
sudo systemctl restart apache2

# ---------- Firewall: port 10000 is reachable only from the VM itself ----------
add_rule INPUT -i lo -p tcp --dport 10000 -j ACCEPT
add_rule INPUT -p tcp --dport 10000 -j DROP

# ---------- Proxy on port 80 ----------
sudo install -m 755 proxyServer.sh /usr/local/bin/proxyServer.sh
sudo install -m 644 proxyServer.service /etc/systemd/system/proxyServer.service
sudo systemctl daemon-reload
sudo systemctl enable --now proxyServer.service

echo "Done. Open http://<VM IP>/ in a browser; Apache itself is not reachable from outside."
