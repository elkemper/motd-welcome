#!/usr/bin/env bash
set -euo pipefail

OVERALL_TIMEOUT="${MOTD_WELCOME_CHECK_TIMEOUT:-120}"
QUERY_TIMEOUT="${MOTD_WELCOME_CHECK_QUERY_TIMEOUT:-15}"
PARALLEL="${MOTD_WELCOME_CHECK_PARALLEL:-4}"

if [[ -z "${MOTD_WELCOME_CHECK_INNER:-}" ]]; then
  export MOTD_WELCOME_CHECK_INNER=1
  if command -v timeout >/dev/null 2>&1; then
    exec timeout --kill-after=10s "$OVERALL_TIMEOUT" "$0" "$@"
  fi
fi

CACHE_DIR="${MOTD_WELCOME_CACHE_DIR:-/var/cache/motd-welcome}"
CACHE_FILE="$CACHE_DIR/images.json"
LOCK_FILE="$CACHE_DIR/.lock"

umask 022
mkdir -p "$CACHE_DIR"
chmod 0755 "$CACHE_DIR"

exec 9>"$LOCK_FILE"
flock -n 9 || exit 0

command -v docker >/dev/null 2>&1 || exit 0
command -v jq >/dev/null 2>&1 || exit 0

if ! timeout 5 docker buildx version >/dev/null 2>&1; then
  printf 'motd-welcome-update-check: docker buildx is not available\n' >&2
  exit 0
fi

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

OLD_CACHE="$TMP_DIR/old.json"
RESULTS="$TMP_DIR/results.tsv"
: >"$RESULTS"
printf '{}\n' >"$OLD_CACHE"
if [[ -r "$CACHE_FILE" ]] && jq -e . "$CACHE_FILE" >/dev/null 2>&1; then
  cp "$CACHE_FILE" "$OLD_CACHE"
fi

if ! ids=$(timeout 5 docker ps -q 2>/dev/null); then
  printf 'motd-welcome-update-check: docker ps failed\n' >&2
  exit 0
fi

images=()
if [[ -n "$ids" ]]; then
  mapfile -t cids <<<"$ids"
  if ! image_list=$(timeout 10 docker inspect --format '{{.Config.Image}}' "${cids[@]}" 2>/dev/null); then
    printf 'motd-welcome-update-check: docker inspect failed\n' >&2
    exit 0
  fi
  mapfile -t images < <(printf '%s\n' "$image_list" | awk 'NF' | sort -u)
fi

if ((${#images[@]})); then
  export QUERY_TIMEOUT
  printf '%s\n' "${images[@]}" | xargs -r -P "$PARALLEL" -n 1 bash -c '
    img="$1"
    if out=$(timeout "$QUERY_TIMEOUT" docker buildx imagetools inspect --format "{{.Manifest.Digest}}" "$img" 2>/dev/null) && [[ -n "$out" ]]; then
      printf "%s\t%s\n" "$img" "$out"
    else
      printf "%s\t\n" "$img"
      printf "motd-welcome-update-check: failed: %s\n" "$img" >&2
    fi
  ' _ >>"$RESULTS" || true
fi

declare -A seen=()
while IFS=$'\t' read -r img _; do
  [[ -n "$img" ]] && seen["$img"]=1
done <"$RESULTS"
for img in "${images[@]}"; do
  [[ -n "${seen[$img]:-}" ]] || printf '%s\t\n' "$img" >>"$RESULTS"
done

result=$(jq -c -n --slurpfile old "$OLD_CACHE" --rawfile rows "$RESULTS" '
  ($old[0].images // {} | if type == "object" then . else {} end) as $old_images
  | ($rows
     | split("\n")
     | map(select(length > 0) | split("\t") | {key: .[0], value: (.[1] // "")})
    ) as $parsed
  | reduce $parsed[] as $row ({};
      if ($row.value | length) > 0 then
        .[$row.key] = {digests: [$row.value]}
      elif $old_images[$row.key] != null then
        .[$row.key] = $old_images[$row.key]
      else
        .[$row.key] = {digests: []}
      end
    )
')

jq -n --arg ts "$(date -u +%FT%TZ)" --argjson imgs "$result" \
  '{checked_at: $ts, images: $imgs}' >"$CACHE_FILE.tmp"
mv "$CACHE_FILE.tmp" "$CACHE_FILE"
chmod 0644 "$CACHE_FILE"
