# MOTD-Welcome
Welcome message for ssh sign in. Prints stats about running docker containers and services exposed by Tailscale.

## Example

┌────────────────────────────────────────────────────────────┐
│ your-host | 192.168.31.1                                   │
│ up 1d 05h | load 0.53 | mem 1.8G / 12.0G                   │
└────────────────────────────────────────────────────────────┘

  <style='color:light-green'>●</style> api                    8080       3d 04h    0.31%   210.5MiB   
  ● cache                  —          3d 04h    0.02%   48.2MiB    
  ● db                     5432       3d 04h    0.18%   512.0MiB   
  ● worker                 9000 +1    3d 04h    0.07%   128.4MiB   ↑ new

tailscale serve
  ● admin          443    https://admin.example.ts.net
  ● metrics        9090   https://metrics.example.ts.net
