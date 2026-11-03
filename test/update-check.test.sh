#!/usr/bin/env bash
set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$here/lib.sh"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin"

cat > "$tmp/bin/docker" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
case "${1:-}" in
  ps)
    [[ "${FAIL_PS:-}" == 1 ]] && exit 1
    [[ "${NO_CONTAINERS:-}" == 1 ]] && exit 0
    printf '%s\n' c1 c2 c3
    ;;
  inspect)
    if [[ "${2:-}" == "--format" ]]; then
      for id in "${@:4}"; do
        case "$id" in
          c1) printf 'lscr.io/linuxserver/radarr:latest\n' ;;
          c2) printf 'lscr.io/linuxserver/sonarr:latest\n' ;;
          c3) printf 'example.com/new/image:latest\n' ;;
        esac
      done
    else
      exit 1
    fi
    ;;
  buildx)
    if [[ "${2:-} ${3:-}" == "version " ]]; then
      [[ "${FAIL_BUILDX:-}" == 1 ]] && exit 1
      exit 0
    fi
    if [[ "${2:-} ${3:-}" == "imagetools inspect" ]]; then
      img="${!#}"
      if [[ "${SLEEP_ALL:-}" == 1 ]]; then
        sleep "${SLEEP_SECS:-1}"
      fi
      if [[ -n "${SLEEP_IMAGE:-}" && "$img" == "$SLEEP_IMAGE" ]]; then
        [[ -n "${SLEEP_PID_FILE:-}" ]] && printf '%s\n' "$$" >"$SLEEP_PID_FILE"
        exec sleep "${SLEEP_SECS:-5}"
      fi
      if [[ -n "${FAIL_IMAGE:-}" && "$img" == "$FAIL_IMAGE" ]]; then
        exit 1
      fi
      awk -F'\t' -v img="$img" '$1 == img { print $2; found=1; exit } END { exit found ? 0 : 1 }' "$REMOTE_TSV"
      exit
    fi
    exit 1
    ;;
  *)
    exit 1
    ;;
esac
STUB

cat > "$tmp/bin/regctl" <<'STUB'
#!/usr/bin/env bash
touch "$MARKER"
exit 1
STUB

chmod +x "$tmp/bin/docker" "$tmp/bin/regctl"
export PATH="$tmp/bin:$PATH"
export REMOTE_TSV="$tmp/remote.tsv"
export MARKER="$tmp/regctl-called"

old_cache() {
  mkdir -p "$1"
  cat > "$1/images.json" <<'JSON'
{"checked_at":"2000-01-01T00:00:00Z","images":{"lscr.io/linuxserver/radarr:latest":{"digests":["old-radarr"]},"lscr.io/linuxserver/sonarr:latest":{"digests":["old-sonarr"]},"stale/image:latest":{"digests":["stale"]}}}
JSON
}

printf 'lscr.io/linuxserver/radarr:latest\tnew-radarr\nexample.com/new/image:latest\tnew-image\n' > "$REMOTE_TSV"

cache_dir="$tmp/cache"
old_cache "$cache_dir"
MOTD_WELCOME_CACHE_DIR="$cache_dir" MOTD_WELCOME_CHECK_QUERY_TIMEOUT=2 "$checker" 2>"$tmp/first.err"

cache="$cache_dir/images.json"
jq empty "$cache" || fail "checker produced invalid json"
[[ "$(stat -c %a "$cache")" == 644 ]] || fail "checker cache mode"
jq -e '.images | length == 3' "$cache" >/dev/null || fail "checker image count"
jq -e '.images | has("stale/image:latest") | not' "$cache" >/dev/null || fail "stale image not pruned"
jq -e '.images["lscr.io/linuxserver/radarr:latest"].digests == ["new-radarr"]' "$cache" >/dev/null \
  || fail "buildx digest not stored"
jq -e '.images["lscr.io/linuxserver/sonarr:latest"].digests == ["old-sonarr"]' "$cache" >/dev/null \
  || fail "old digest not preserved on buildx failure"
jq -e '.images["example.com/new/image:latest"].digests == ["new-image"]' "$cache" >/dev/null \
  || fail "new image digest missing"
jq -e '.checked_at | test("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$")' "$cache" >/dev/null \
  || fail "checked_at format"
[[ ! -e "$MARKER" ]] || fail "regctl fallback was used"
ok "update-check: buildx only, preserve old, prune stale"

cache_dir="$tmp/parallel"
old_cache "$cache_dir"
start=$(date +%s)
SLEEP_ALL=1 SLEEP_SECS=1 \
  MOTD_WELCOME_CACHE_DIR="$cache_dir" \
  MOTD_WELCOME_CHECK_PARALLEL=3 \
  MOTD_WELCOME_CHECK_QUERY_TIMEOUT=5 \
  "$checker" 2>"$tmp/parallel.err"
elapsed=$(( $(date +%s) - start ))
(( elapsed < 3 )) || fail "parallel check took ${elapsed}s"
ok "update-check: parallel requests"

cache_dir="$tmp/query-timeout"
old_cache "$cache_dir"
export SLEEP_PID_FILE="$tmp/sleep.pid"
start=$(date +%s)
SLEEP_IMAGE="lscr.io/linuxserver/radarr:latest" SLEEP_SECS=10 \
  MOTD_WELCOME_CACHE_DIR="$cache_dir" \
  MOTD_WELCOME_CHECK_QUERY_TIMEOUT=1 \
  "$checker" 2>"$tmp/query-timeout.err"
elapsed=$(( $(date +%s) - start ))
(( elapsed < 4 )) || fail "per-image timeout took ${elapsed}s"
jq -e '.images["lscr.io/linuxserver/radarr:latest"].digests == ["old-radarr"]' "$cache_dir/images.json" >/dev/null \
  || fail "per-image timeout did not preserve old digest"
ok "update-check: per-image timeout"

cache_dir="$tmp/ps-fail"
old_cache "$cache_dir"
MOTD_WELCOME_CACHE_DIR="$cache_dir" FAIL_PS=1 "$checker" 2>"$tmp/ps-fail.err"
jq -e '.checked_at == "2000-01-01T00:00:00Z"' "$cache_dir/images.json" >/dev/null \
  || fail "cache changed after docker ps failure"
ok "update-check: docker ps failure keeps cache"

cache_dir="$tmp/no-containers"
old_cache "$cache_dir"
NO_CONTAINERS=1 MOTD_WELCOME_CACHE_DIR="$cache_dir" "$checker"
jq -e '.images == {}' "$cache_dir/images.json" >/dev/null || fail "no-container cache is not empty"
jq -e '.checked_at != "2000-01-01T00:00:00Z"' "$cache_dir/images.json" >/dev/null \
  || fail "no-container cache was not refreshed"
ok "update-check: no running containers"

cache_dir="$tmp/no-buildx"
old_cache "$cache_dir"
set +e
MOTD_WELCOME_CACHE_DIR="$cache_dir" FAIL_BUILDX=1 "$checker" 2>"$tmp/no-buildx.err"
rc=$?
set -e
[[ "$rc" -eq 0 ]] || fail "missing buildx should not fail the service"
grep -qi buildx "$tmp/no-buildx.err" || fail "missing buildx is not logged"
jq -e '.checked_at == "2000-01-01T00:00:00Z"' "$cache_dir/images.json" >/dev/null \
  || fail "cache changed after buildx failure"
ok "update-check: missing buildx keeps cache"

cache_dir="$tmp/timeout"
old_cache "$cache_dir"
start=$(date +%s)
set +e
MOTD_WELCOME_CACHE_DIR="$cache_dir" \
  MOTD_WELCOME_CHECK_TIMEOUT=2 \
  MOTD_WELCOME_CHECK_QUERY_TIMEOUT=30 \
  SLEEP_IMAGE="lscr.io/linuxserver/radarr:latest" \
  SLEEP_SECS=10 \
  SLEEP_PID_FILE="$tmp/overall-sleep.pid" \
  timeout 6 "$checker" 2>"$tmp/overall-timeout.err"
rc=$?
set -e
elapsed=$(( $(date +%s) - start ))
[[ "$rc" -eq 124 ]] || fail "overall timeout did not fire"
(( elapsed < 5 )) || fail "overall timeout took ${elapsed}s"
[[ -f "$tmp/overall-sleep.pid" ]] && kill "$(cat "$tmp/overall-sleep.pid")" 2>/dev/null || true
jq -e '.checked_at == "2000-01-01T00:00:00Z"' "$cache_dir/images.json" >/dev/null \
  || fail "cache changed after overall timeout"
ok "update-check: overall timeout"
