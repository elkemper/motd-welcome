#!/usr/bin/env bash
set -euo pipefail

src=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

install -m 0755 "$src/motd-welcome.sh" /etc/update-motd.d/00-motd-welcome
install -m 0755 "$src/motd-welcome-update-check.sh" /usr/local/bin/motd-welcome-update-check
install -m 0644 "$src/motd-welcome-update-check.service" /etc/systemd/system/motd-welcome-update-check.service
install -m 0644 "$src/motd-welcome-update-check.timer" /etc/systemd/system/motd-welcome-update-check.timer
install -d -m 0755 /var/cache/motd-welcome

systemctl daemon-reload
systemctl enable --now motd-welcome-update-check.timer

printf 'installed\n'
printf 'run: systemctl start motd-welcome-update-check.service\n'
