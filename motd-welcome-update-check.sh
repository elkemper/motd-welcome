#!/usr/bin/env bash
set -euo pipefail

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

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

remote_digests() {
  local img="$1" out tmp
  if command -v regctl >/dev/null 2>&1; then
    if out=$(regctl image digest "$img" 2>/dev/null) && [[ -n "$out" ]]; then
      printf '["%s"]\n' "$out"
      return 0
    fi
  fi
  if command -v crane >/dev/null 2>&1; then
    if out=$(crane digest "$img" 2>/dev/null) && [[ -n "$out" ]]; then
      printf '["%s"]\n' "$out"
      return 0
    fi
  fi
  if command -v skopeo >/dev/null 2>&1; then
    tmp="$TMP_DIR/raw"
    if skopeo inspect --raw "docker://$img" >"$tmp" 2>/dev/null; then
      out="sha256:$(sha256sum "$tmp" | cut -d' ' -f1)"
      printf '["%s"]\n' "$out"
      return 0
    fi
  fi
  if docker buildx version >/dev/null 2>&1; then
    if out=$(docker buildx imagetools inspect --format '{{.Manifest.Digest}}' "$img" 2>/dev/null) && [[ -n "$out" ]]; then
      printf '["%s"]\n' "$out"
      return 0
    fi
  fi
  out=$(docker manifest inspect --verbose "$img" 2>/dev/null | jq -c '[if type == "array" then .[] else . end | .Descriptor.digest // empty] | unique' 2>/dev/null || true)
  if [[ -n "$out" ]]; then
    printf '%s\n' "$out"
  else
    printf '[]\n'
  fi
}

mapfile -t ids < <(docker ps -q 2>/dev/null || true)
images=()
if ((${#ids[@]})); then
  mapfile -t images < <(docker inspect --format '{{.Config.Image}}' "${ids[@]}" 2>/dev/null | sort -u || true)
fi

result='{}'
for img in "${images[@]}"; do
  [[ -z "$img" ]] && continue
  digests=$(remote_digests "$img")
  [[ -z "$digests" ]] && digests='[]'
  result=$(jq -c --arg k "$img" --argjson v "$digests" '. + {($k): {digests: $v}}' <<<"$result")
done

jq -n --arg ts "$(date -u +%FT%TZ)" --argjson imgs "$result" \
  '{checked_at: $ts, images: $imgs}' >"$CACHE_FILE.tmp"
mv "$CACHE_FILE.tmp" "$CACHE_FILE"
chmod 0644 "$CACHE_FILE"
