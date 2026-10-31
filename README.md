# Linux Network Services

Four small network services for Ubuntu, built with Bash, [socat](http://www.dest-unreach.org/socat/), systemd and iptables. Each one installs on a fresh machine with a single script and starts automatically on boot.

| Project | What it does | Key topics |
| --- | --- | --- |
| [TCP API Server](tcp-api-server) | A server and client that talk over a custom text protocol on top of TCP, with a handshake and a small query API | TCP sockets, protocol design, input validation, systemd |
| [FTP Access Control](ftp-access-control) | An authentication service that opens or closes FTP access for a client’s IP with iptables after checking its key | iptables, firewall rules, vsftpd, access control |
| [Reverse Proxy Gate](reverse-proxy-gate) | A proxy on port 80 that decides per request what to serve, while Apache itself is hidden on a local-only port | HTTP, reverse proxy, iptables, Apache |
| [ARP Monitor](arp-monitor) | Logs the machine’s ARP cache every two minutes | systemd timers, `ip neigh`, journald |

## How the services are built

All services follow the same pattern. `socat` listens on a TCP port and, for every incoming connection, starts a separate Bash process whose stdin and stdout are connected to the socket. The script reads requests with `read` and replies with `echo`, so each client is handled in isolation. A systemd unit keeps `socat` running, restarts it after a crash and starts it on boot. An `install.sh` script in each folder installs the packages, copies the files to their system locations and enables the service without any prompts.

## Quick start

The services change firewall rules and system configuration, so run them in a virtual machine. With [Multipass](https://multipass.run/):

```bash
multipass launch 24.04 --name lab
multipass mount . lab:/home/ubuntu/linux-network-services
multipass shell lab

cd linux-network-services/tcp-api-server
./install.sh
```

Each folder has its own README with usage details. The services use different ports (4242, 7777 and 21, 80, 10000), so all four can run on one machine.

> iptables rules added by these scripts are not saved across reboots. To keep them, install `iptables-persistent` and run `sudo netfilter-persistent save`.

## License

[MIT](LICENSE)
