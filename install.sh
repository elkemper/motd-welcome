#!/usr/bin/env bash
set -euo pipefail

dest="${DESTDIR:-}"
etcdir="${dest}/etc"
bindir="${dest}/usr/local/bin"
unitdir="${etcdir}/systemd/system"
cachedir="${dest}/var/cache/motd-welcome"

targets=(
  "$etcdir/update-motd.d/00-motd-welcome"
  "$bindir/motd-welcome-update-check"
  "$bindir/motd-welcome-stats"
  "$unitdir/motd-welcome-update-check.service"
  "$unitdir/motd-welcome-update-check.timer"
  "$unitdir/motd-welcome-stats.service"
  "$unitdir/motd-welcome-stats.timer"
)

for target in "${targets[@]}"; do
  if [[ -e "$target" ]]; then
    printf 'motd-welcome already installed; run ./uninstall.sh first\n' >&2
    exit 1
  fi
done

if [[ -z "$dest" && $EUID -ne 0 ]]; then
  printf 'run as root\n' >&2
  exit 1
fi

required=(
  docker jq flock timeout systemctl install
  mktemp awk hostname date sort xargs
  cp mv mkdir chmod rm dirname
)
missing=()
for cmd in "${required[@]}"; do
  command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
done
if ((${#missing[@]})); then
  printf 'missing dependencies: %s\n' "${missing[*]}" >&2
  exit 1
fi

src=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/src

if ! docker buildx version >/dev/null 2>&1; then
  printf 'warning: docker buildx is not available; image update checks will be skipped\n' >&2
fi

if command -v locale >/dev/null 2>&1; then
  have_utf8=0
  while IFS= read -r loc; do
    case "${loc,,}" in
      c.utf8|c.utf-8) have_utf8=1 ;;
    esac
  done < <(locale -a 2>/dev/null)
  if ((have_utf8 == 0)); then
    printf 'warning: C.UTF-8 locale is not available; MOTD alignment may be broken\n' >&2
  fi
fi

install -d -m 0755 "$etcdir/update-motd.d" "$bindir" "$unitdir" "$cachedir"

install -m 0755 "$src/motd-welcome.sh" "$etcdir/update-motd.d/00-motd-welcome"
install -m 0755 "$src/motd-welcome-update-check.sh" "$bindir/motd-welcome-update-check"
install -m 0755 "$src/motd-welcome-stats.sh" "$bindir/motd-welcome-stats"
install -m 0644 "$src/systemd/motd-welcome-update-check.service" "$unitdir/motd-welcome-update-check.service"
install -m 0644 "$src/systemd/motd-welcome-update-check.timer" "$unitdir/motd-welcome-update-check.timer"
install -m 0644 "$src/systemd/motd-welcome-stats.service" "$unitdir/motd-welcome-stats.service"
install -m 0644 "$src/systemd/motd-welcome-stats.timer" "$unitdir/motd-welcome-stats.timer"

if [[ -z "$dest" ]]; then
  systemctl daemon-reload
  systemctl enable --now motd-welcome-update-check.timer
  systemctl enable --now motd-welcome-stats.timer
  systemctl start motd-welcome-stats.service
  systemctl start --no-block motd-welcome-update-check.service
fi

printf 'installed\n'
