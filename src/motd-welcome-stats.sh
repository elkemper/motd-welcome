#!/usr/bin/env bash
set -euo pipefail

CACHE_DIR="${MOTD_WELCOME_CACHE_DIR:-/var/cache/motd-welcome}"
STATS_FILE="${MOTD_WELCOME_STATS_CACHE:-$CACHE_DIR/stats.tsv}"
if [[ -n "${MOTD_WELCOME_STATS_CACHE:-}" ]]; then
  CACHE_DIR=$(dirname "$STATS_FILE")
fi
LOCK_FILE="$CACHE_DIR/.stats.lock"

umask 022
mkdir -p "$CACHE_DIR"
chmod 0755 "$CACHE_DIR"

exec 9>"$LOCK_FILE"
flock -n 9 || exit 0

command -v docker >/dev/null 2>&1 || exit 0

tmp=$(mktemp "$CACHE_DIR/.stats.tmp.XXXXXX")
trap 'rm -f "$tmp"' EXIT

if ! timeout 10 docker stats --no-stream --format $'{{.ID}}\t{{.CPUPerc}}\t{{.MemUsage}}' >"$tmp" 2>/dev/null; then
  exit 0
fi

chmod 0644 "$tmp"
mv "$tmp" "$STATS_FILE"
