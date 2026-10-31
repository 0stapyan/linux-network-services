# ARP Monitor

A systemd timer that logs the machine’s ARP cache, the IP and MAC addresses of its network neighbours, every two minutes.

```
Oct 31 10:00 : 10.0.0.1 52:54:00:12:34:56 10.0.0.7 52:54:00:ab:cd:ef
```

The script reads the cache with `ip neigh`, which is available on every modern Linux system, so nothing extra needs to be installed. A `oneshot` service runs the script, and a timer triggers that service one minute after boot and then every two minutes.

## Install

```bash
./install.sh
```

## Use

```bash
journalctl -u arp-monitor          # see the logged entries
systemctl list-timers arp-monitor  # see when it runs next
sudo systemctl stop arp-monitor.timer
```

## Files

| File | Purpose |
| --- | --- |
| `arp-monitor.sh` | Prints the time and the ARP cache on one line |
| `arp-monitor.service` | Runs the script once |
| `arp-monitor.timer` | Triggers the service every two minutes |
| `install.sh` | Installs and enables the timer |
