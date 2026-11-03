# MOTD-Welcome
Welcome message for interactive SSH logins. Prints stats about running Docker containers and services exposed by Tailscale.

## Example
<pre>
┌────────────────────────────────────────────────────────────┐
│ your-host | 192.0.2.10                                     │
│ up 1d 05h | load 0.53 | mem 1.8G / 12.0G                   │
└────────────────────────────────────────────────────────────┘

  ● api                    8080       3d 04h    0.31%   210.5MiB
  ● cache                  —          3d 04h    0.02%   48.2MiB
  ● db                     5432       3d 04h    0.18%   512.0MiB
  ● worker                 9000 +1    3d 04h    0.07%   128.4MiB   ↑ new

tailscale serve
  ● admin          443    https://admin.example.ts.net
  ● metrics        9090   https://metrics.example.ts.net
</pre>

## Requirements
- Docker and systemd
- coreutils, `awk`, `flock`, `xargs`, `jq`
- a UTF-8 locale (`C.UTF-8`) for correct MOTD alignment
- `docker buildx` for image update checks (optional; install prints a warning if missing)
- `tailscale` for the `tailscale serve` section (optional)

## Installation
Run the install script as root:
```bash
sudo ./install.sh
```

If any part of MOTD-Welcome is already installed, the script exits with an error. Run `./uninstall.sh` first.

## Uninstall
```bash
sudo ./uninstall.sh
```

Uninstall removes the installed files and the `/var/cache/motd-welcome` cache.

## How it works
The install script puts the renderer into `/etc/update-motd.d/00-motd-welcome` and installs 2 services + 2 timers:
- stats service/timer collects CPU and memory usage every minute;
- update-check service/timer checks for new container images every 6 hours using `docker buildx`.

MOTD is shown only for interactive TTY logins; cron and non-interactive SSH sessions are not affected.

## Development
Source files live in `src/`, systemd units in `src/systemd/`, and tests in `test/`:
```bash
./test/run-tests.sh
```
