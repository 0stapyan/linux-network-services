#!/bin/bash
# Sets up an FTP server with IP-based access control on Ubuntu.
# Usage: ./install.sh <comma-separated list of IPs allowed to use FTP>
# Example: ./install.sh 192.168.0.105,10.10.1.2
set -euo pipefail
cd "$(dirname "$0")"

FTP_USER="ftp_user"
FTP_PASSWORD='MyFTPPass!'   # demo password, change it for any real use

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <comma-separated list of IPs>"
    exit 1
fi

IFS=',' read -ra ALLOWED_IPS <<< "$1"
for ip in "${ALLOWED_IPS[@]}"; do
    if [[ ! "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        echo "Error: '$ip' is not a valid IPv4 address."
        exit 1
    fi
done

# Adds a rule only if it does not exist yet, so the script can be run again safely.
add_rule() {
    sudo iptables -C "$@" 2>/dev/null || sudo iptables -A "$@"
}

# ---------- Packages ----------
sudo apt-get update -y
sudo apt-get install -y vsftpd socat iptables

# ---------- Firewall ----------
# Block ping (ICMP echo requests) from any host
add_rule INPUT -p icmp --icmp-type echo-request -j DROP

# Allow FTP only from the given IPs, drop it for everyone else
for ip in "${ALLOWED_IPS[@]}"; do
    add_rule INPUT -s "$ip" -p tcp --dport 21 -j ACCEPT
done
add_rule INPUT -p tcp --dport 21 -j DROP

# ---------- FTP server ----------
sudo sed -i 's/^#\?local_enable=.*/local_enable=YES/' /etc/vsftpd.conf
sudo sed -i 's/^#\?write_enable=.*/write_enable=YES/' /etc/vsftpd.conf
grep -q '^pasv_min_port=' /etc/vsftpd.conf || echo "pasv_min_port=40000" | sudo tee -a /etc/vsftpd.conf > /dev/null
grep -q '^pasv_max_port=' /etc/vsftpd.conf || echo "pasv_max_port=40010" | sudo tee -a /etc/vsftpd.conf > /dev/null
sudo systemctl enable vsftpd
sudo systemctl restart vsftpd

# FTP user, created without interactive prompts
id "$FTP_USER" &>/dev/null || sudo adduser --disabled-password --gecos "" "$FTP_USER"
echo "$FTP_USER:$FTP_PASSWORD" | sudo chpasswd

for file in 1.txt 2.txt; do
    echo "Hello World!" | sudo tee "/home/$FTP_USER/$file" > /dev/null
done
sudo chown "$FTP_USER:$FTP_USER" "/home/$FTP_USER/1.txt" "/home/$FTP_USER/2.txt"

# ---------- Authentication server ----------
sudo install -m 755 authServer.sh /usr/bin/authServer.sh
sudo install -d -m 700 /etc/authServer
sudo install -m 600 credentials.txt /etc/authServer/credentials.txt
sudo install -m 644 authServer.service /etc/systemd/system/authServer.service
sudo systemctl daemon-reload
sudo systemctl enable --now authServer.service

echo "Done. FTP is open for: $1. Other clients can authenticate on port 7777."
