# MOTD-Welcome
Welcome message for ssh sign in. Prints stats about running docker containers and services exposed by Tailscale.

## Example
<pre>
┌────────────────────────────────────────────────────────────┐  
│ your-host | 192.168.31.1                                   │  
│ up 1d 05h | load 0.53 | mem 1.8G / 12.0G                   │  
└────────────────────────────────────────────────────────────┘  

  🟢 api                    8080       3d 04h    0.31%   210.5MiB   
  🟢 cache                  —          3d 04h    0.02%   48.2MiB    
  🟢 db                     5432       3d 04h    0.18%   512.0MiB   
  🟢 worker                 9000 +1    3d 04h    0.07%   128.4MiB   ↑ new

tailscale serve
  🟢 admin          443    https://admin.example.ts.net
  🟢 metrics        9090   https://metrics.example.ts.net
</pre>

## Installation
Run the install script by root:
```bash
sudo ./install.sh
```

## Uninstall
```bash
sudo ./uninstall.sh
```

## How it works
Install script will put the main script `motd-welcome.sh` into `/etc/update-motd.d/00-motd-welcome` and will set 2 new services (using `systemctl`) - one will get containers stats like CPU and MEM usage each minute, another will check (every 6 hours) if there is new images for the containers you have installed. No auth or private registries supported.
