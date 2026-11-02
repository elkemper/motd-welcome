#!/usr/bin/env bash
set -euo pipefail

[[ $EUID -eq 0 ]] || { printf 'run as root\n' >&2; exit 1; }

systemctl disable --now motd-welcome-stats.timer 2>/dev/null || true
systemctl disable --now motd-welcome-update-check.timer 2>/dev/null || true
systemctl stop motd-welcome-stats.service 2>/dev/null || true
systemctl stop motd-welcome-update-check.service 2>/dev/null || true

rm -f /etc/update-motd.d/00-motd-welcome
rm -f /usr/local/bin/motd-welcome-update-check
rm -f /usr/local/bin/motd-welcome-stats
rm -f /etc/systemd/system/motd-welcome-update-check.service
rm -f /etc/systemd/system/motd-welcome-update-check.timer
rm -f /etc/systemd/system/motd-welcome-stats.service
rm -f /etc/systemd/system/motd-welcome-stats.timer

systemctl daemon-reload
systemctl reset-failed motd-welcome-update-check.service motd-welcome-stats.service 2>/dev/null || true

rm -rf /var/cache/motd-welcome

printf 'uninstalled\n'
