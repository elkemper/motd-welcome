#!/usr/bin/env bash
set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$here/lib.sh"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin" "$tmp/emptybin"
ln -s "$(command -v dirname)" "$tmp/emptybin/dirname"

cat > "$tmp/bin/docker" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
[[ "${1:-} ${2:-}" == "buildx version" ]] && exit 0
exit 1
STUB

cat > "$tmp/bin/systemctl" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$SYSTEMCTL_LOG"
exit 0
STUB

chmod +x "$tmp/bin/docker" "$tmp/bin/systemctl"
export SYSTEMCTL_LOG="$tmp/systemctl.log"
export PATH="$tmp/bin:$PATH"

dest="$tmp/root"
mkdir -p "$dest/etc/systemd/system"
touch "$dest/etc/systemd/system/motd-welcome-stats.timer"

set +e
PATH="$tmp/emptybin" DESTDIR="$dest" /bin/bash "$installer" >"$tmp/guard.out" 2>"$tmp/guard.err"
rc=$?
set -e
[[ "$rc" -eq 1 ]] || fail "install should fail when already installed"
grep -qi uninstall "$tmp/guard.err" || fail "install guard does not mention uninstall"
[[ ! -e "$dest/usr/local/bin/motd-welcome-update-check" ]] || fail "guard performed a partial install"
ok "install: refuses existing installation"

guard_dest="$tmp/guard-root"
set +e
PATH="$tmp/emptybin" DESTDIR="$guard_dest" /bin/bash "$installer" >"$tmp/deps.out" 2>"$tmp/deps.err"
rc=$?
set -e
[[ "$rc" -eq 1 ]] || fail "install should fail on missing dependencies"
grep -qi 'missing' "$tmp/deps.err" || fail "missing dependencies are not reported"
grep -q 'docker' "$tmp/deps.err" || fail "docker is not listed as missing"
grep -q 'jq' "$tmp/deps.err" || fail "jq is not listed as missing"
grep -q 'xargs' "$tmp/deps.err" || fail "xargs is not listed as missing"
ok "install: checks required dependencies"

dest="$tmp/clean"
DESTDIR="$dest" "$installer" >"$tmp/clean.out" 2>"$tmp/clean.err"

[[ -x "$dest/etc/update-motd.d/00-motd-welcome" ]] || fail "renderer missing"
[[ -x "$dest/usr/local/bin/motd-welcome-update-check" ]] || fail "update-check missing"
[[ -x "$dest/usr/local/bin/motd-welcome-stats" ]] || fail "stats missing"
for unit in \
  motd-welcome-update-check.service \
  motd-welcome-update-check.timer \
  motd-welcome-stats.service \
  motd-welcome-stats.timer; do
  [[ -f "$dest/etc/systemd/system/$unit" ]] || fail "missing unit $unit"
done
[[ -d "$dest/var/cache/motd-welcome" ]] || fail "cache dir missing"
[[ ! -s "$SYSTEMCTL_LOG" ]] || fail "staged install must not call systemctl"
ok "install: staged install"

DESTDIR="$dest" "$uninstaller" >"$tmp/uninstall.out" 2>"$tmp/uninstall.err"
[[ ! -e "$dest/etc/update-motd.d/00-motd-welcome" ]] || fail "renderer not removed"
[[ ! -e "$dest/usr/local/bin/motd-welcome-update-check" ]] || fail "update-check not removed"
[[ ! -e "$dest/etc/systemd/system/motd-welcome-update-check.timer" ]] || fail "timer not removed"
[[ ! -e "$dest/var/cache/motd-welcome" ]] || fail "cache not removed"
[[ ! -s "$SYSTEMCTL_LOG" ]] || fail "staged uninstall must not call systemctl"
ok "uninstall: staged remove"
