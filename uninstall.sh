#!/usr/bin/env bash
set -euo pipefail

dest="${DESTDIR:-}"
etcdir="${dest}/etc"
bindir="${dest}/usr/local/bin"
unitdir="${etcdir}/systemd/system"
cachedir="${dest}/var/cache/motd-welcome"

if [[ -z "$dest" && $EUID -ne 0 ]]; then
  printf 'run as root\n' >&2
  exit 1
fi

if [[ -z "$dest" ]]; then
  systemctl disable --now motd-welcome-stats.timer 2>/dev/null || true
  systemctl disable --now motd-welcome-update-check.timer 2>/dev/null || true
  systemctl stop motd-welcome-stats.service 2>/dev/null || true
  systemctl stop motd-welcome-update-check.service 2>/dev/null || true
fi

rm -f "$etcdir/update-motd.d/00-motd-welcome"
rm -f "$bindir/motd-welcome-update-check"
rm -f "$bindir/motd-welcome-stats"
rm -f "$unitdir/motd-welcome-update-check.service"
rm -f "$unitdir/motd-welcome-update-check.timer"
rm -f "$unitdir/motd-welcome-stats.service"
rm -f "$unitdir/motd-welcome-stats.timer"

if [[ -z "$dest" ]]; then
  systemctl daemon-reload
  systemctl reset-failed motd-welcome-update-check.service motd-welcome-stats.service 2>/dev/null || true
fi

rm -rf "$cachedir"

printf 'uninstalled\n'
