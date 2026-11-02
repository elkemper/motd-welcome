#!/usr/bin/env bash
set -uo pipefail

CACHE_FILE="${MOTD_WELCOME_CACHE:-/var/cache/motd-welcome/images.json}"
STATS_FILE="${MOTD_WELCOME_STATS_CACHE:-/var/cache/motd-welcome/stats.tsv}"
NOW=$(date +%s)

TMP_DIR=$(mktemp -d 2>/dev/null || true)
if [[ -n "$TMP_DIR" ]]; then
  trap 'rm -rf "$TMP_DIR"' EXIT
fi

green=$'\033[32m●\033[0m'
yellow=$'\033[33m●\033[0m'
red=$'\033[31m●\033[0m'

human_duration() {
  local s="${1:-0}" d h m
  ((s < 0)) && s=0
  d=$((s / 86400))
  h=$((s % 86400 / 3600))
  m=$((s % 3600 / 60))
  if ((d > 0)); then
    printf '%dd %02dh' "$d" "$h"
  elif ((h > 0)); then
    printf '%dh %02dm' "$h" "$m"
  else
    printf '%dm' "$m"
  fi
}

human_kb() {
  awk -v k="${1:-0}" 'BEGIN {
    if (k >= 1048576) printf "%.1fG", k / 1048576;
    else if (k >= 1024) printf "%dM", k / 1024;
    else printf "%dK", k
  }'
}

fitvar() {
  local s="$1" w="$2" out="$3"
  if ((${#s} > w)); then
    if ((w > 2)); then
      s="${s:0:$((w - 2))}.."
    else
      s="${s:0:$w}"
    fi
  fi
  printf -v "$out" '%s' "$s"
}

padvar() {
  local s="$1" w="$2" out="$3" n
  n=${#s}
  if ((n < w)); then
    printf -v "$out" '%s%*s' "$s" $((w - n)) ''
  else
    printf -v "$out" '%s' "$s"
  fi
}

host=$(hostname -s 2>/dev/null || hostname)
ip=$(hostname -I 2>/dev/null | awk '{print $1}')
[[ -z "$ip" ]] && ip="no-ip"
read -r up_s _ < /proc/uptime || up_s=0
up_s=${up_s%.*}
host_up=$(human_duration "$up_s")
load=$(awk '{print $1}' /proc/loadavg 2>/dev/null || printf '?')
mem_total=$(awk '/^MemTotal:/{print $2}' /proc/meminfo 2>/dev/null)
mem_avail=$(awk '/^MemAvailable:/{print $2}' /proc/meminfo 2>/dev/null)
mem_used=$(( ${mem_total:-0} - ${mem_avail:-0} ))
hr=$(printf '─%.0s' {1..60})

printf '┌%s┐\n' "$hr"
printf '│ %-58.58s │\n' "$host | $ip"
printf '│ %-58.58s │\n' "up $host_up | load $load | mem $(human_kb "$mem_used") / $(human_kb "$mem_total")"
printf '└%s┘\n\n' "$hr"

if ! command -v docker >/dev/null 2>&1; then
  printf 'docker not available\n'
  exit 0
fi

if ! ids=$(timeout 3 docker ps -q 2>/dev/null); then
  printf 'docker: cannot query containers\n'
  exit 0
fi

if [[ -z "$ids" ]]; then
  printf 'no running containers\n'
  exit 0
fi

mapfile -t cids <<<"$ids"

ts_tmp=""
ts_pid=""
if command -v tailscale >/dev/null 2>&1; then
  ts_tmp="$TMP_DIR/tailscale"
  (timeout 2 tailscale serve status >"$ts_tmp" 2>/dev/null) &
  ts_pid=$!
fi

containers=$(timeout 5 docker inspect "${cids[@]}" 2>/dev/null) || exit 0

declare -A CPU MEM
if [[ -r "$STATS_FILE" ]]; then
  while IFS=$'\t' read -r cid cpu mem; do
    [[ -z "$cid" ]] && continue
    CPU["${cid:0:12}"]="${cpu:-}"
    MEM["${cid:0:12}"]="${mem%% /*}"
  done < "$STATS_FILE"
fi

mapfile -t image_refs < <(jq -r '.[].Config.Image // empty' <<<"$containers" | sort -u)
img_tmp=""
img_pid=""
if ((${#image_refs[@]})); then
  img_tmp="$TMP_DIR/image_map.json"
  (
    timeout 5 docker image inspect "${image_refs[@]}" 2>/dev/null | jq -c '
      [ .[] as $i |
        (($i.RepoDigests // []) | map(sub("^[^@]+@"; ""))) as $d |
        ($i.RepoTags // [])[] as $t |
        {key: $t, value: $d},
        (if ($t | endswith(":latest")) then {key: ($t | sub(":latest$"; "")), value: $d} else empty end)
      ] | from_entries
    ' >"$img_tmp" 2>/dev/null
  ) &
  img_pid=$!
fi

if [[ ! -r "$CACHE_FILE" ]]; then
  (systemctl start motd-welcome-update-check.service >/dev/null 2>&1 &)
fi

if [[ -n "$img_pid" ]]; then
  wait "$img_pid" || true
fi

image_map='{}'
if [[ -n "$img_tmp" && -r "$img_tmp" ]]; then
  image_map=$(cat "$img_tmp" 2>/dev/null || true)
fi
[[ -z "$image_map" ]] && image_map='{}'

declare -A UPDATES
if [[ -r "$CACHE_FILE" ]]; then
  while IFS= read -r ref; do
    [[ -n "$ref" ]] && UPDATES["$ref"]=1
  done < <(jq -r --slurpfile cache "$CACHE_FILE" '
    . as $map
    | ($cache[0].images // {}) as $remote
    | to_entries[]
    | .key as $ref
    | (.value // []) as $local
    | ($remote[$ref].digests // []) as $r
    | select(($local | length) > 0 and ($r | length) > 0)
    | select(any($local[]; . as $d | ($r | index($d))) | not)
    | $ref
  ' <<<"$image_map" 2>/dev/null)
fi

while IFS='|' read -r id name image status health started_epoch ports_raw; do
  [[ -z "$name" ]] && continue

  if [[ "$status" != "running" || "$health" == "unhealthy" ]]; then
    dot=$red
  elif [[ "$health" == "starting" ]]; then
    dot=$yellow
  else
    dot=$green
  fi

  if [[ "$status" == "running" && "$started_epoch" =~ ^[0-9]+$ ]]; then
    up=$(human_duration $((NOW - started_epoch)))
  else
    up="—"
  fi

  ports_field="—"
  [[ -n "$ports_raw" ]] && ports_field="$ports_raw"

  short="${id:0:12}"
  cpu="${CPU[$short]:-—}"
  mem="${MEM[$short]:-—}"
  [[ -z "$cpu" ]] && cpu="—"
  [[ -z "$mem" ]] && mem="—"

  update=""
  [[ -n "${UPDATES[$image]:-}" ]] && update="↑ new"

  fitvar "$name" 22 name_f
  padvar "$name_f" 22 name_p
  padvar "$ports_field" 10 ports_p
  padvar "$up" 9 up_p
  padvar "$cpu" 7 cpu_p
  padvar "$mem" 9 mem_p
  printf '  %s %s %s %s %s %s  %s\n' "$dot" "$name_p" "$ports_p" "$up_p" "$cpu_p" "$mem_p" "$update"
done < <(jq -r '
  def portfield($raw; $numeric):
    ($raw | split(",") | map(select(length > 0)) | unique) as $u
    | (if $numeric then ($u | sort_by(tonumber)) else $u end) as $p
    | if ($p | length) == 0 then ""
      elif ($p | length) == 1 then $p[0]
      else "\($p[0]) +\(($p | length) - 1)"
      end;
  sort_by(.Name)[] |
  ([ (.NetworkSettings.Ports // {}) | to_entries[] | select(.key | endswith("/tcp")) | (.value // [])[] | .HostPort // empty ] | join(",")) as $published |
  ([ (.Config.ExposedPorts // {}) | keys[] | select(endswith("/tcp")) | sub("/tcp$"; "") ] | join(",")) as $exposed_tcp |
  ([ (.Config.ExposedPorts // {}) | keys[] | sub("/[a-z]+$"; "") ] | join(",")) as $exposed_any |
  (if ($published | length) > 0 then portfield($published; true)
   elif ($exposed_tcp | length) > 0 then portfield($exposed_tcp; false)
   else portfield($exposed_any; false) end) as $ports |
  ((.State.StartedAt // "") | sub("\\..*"; "Z") | try fromdateiso8601 catch null) as $started |
  [
    .Id,
    (.Name | ltrimstr("/")),
    (.Config.Image // ""),
    (.State.Status // ""),
    (.State.Health.Status // ""),
    ($started // ""),
    $ports
  ] | join("|")
' <<<"$containers")

tcp_open() {
  local host="$1" port="$2"
  [[ "$port" =~ ^[0-9]+$ ]] || return 1
  timeout 1 bash -c "exec 3<>/dev/tcp/$host/$port" 2>/dev/null
}

ts_lines=()
probe_svc=()
probe_port=()
probe_url=()
probe_pids=()
serve_status=""
if [[ -n "$ts_pid" ]]; then
  wait "$ts_pid" || true
fi
if [[ -n "$ts_tmp" && -r "$ts_tmp" ]]; then
  serve_status=$(cat "$ts_tmp" 2>/dev/null || true)
fi

if [[ -n "$serve_status" ]]; then
  url=""
  svc=""
  probe_n=0
  while IFS= read -r line; do
    if [[ "$line" =~ ^(https?|tcp):// ]]; then
      url=${line%% *}
      svc=""
      if [[ "$line" =~ \(svc:([^\)]+)\) ]]; then
        svc=${BASH_REMATCH[1]}
      fi
      if [[ -z "$svc" ]]; then
        _h=${url#*://}
        _h=${_h%%/*}
        svc=${_h%%.*}
      fi
      continue
    fi
    if [[ -n "$url" && "$line" =~ proxy[[:space:]]+([^[:space:]]+) ]]; then
      target=${BASH_REMATCH[1]}
      _t=${target#*://}
      _t=${_t%%/*}
      thost=${_t%:*}
      tport=${_t##*:}
      if [[ "$thost" == "$_t" ]]; then
        case "$target" in
          https://*) tport=443 ;;
          http://*) tport=80 ;;
          *) tport="" ;;
        esac
      fi
      [[ "$thost" == "localhost" ]] && thost=127.0.0.1
      probe_n=$((probe_n + 1))
      probe_svc+=("$svc")
      probe_port+=("$tport")
      probe_url+=("$url")
      (
        if tcp_open "$thost" "$tport"; then
          printf 'green' >"$TMP_DIR/probe.$probe_n"
        else
          printf 'red' >"$TMP_DIR/probe.$probe_n"
        fi
      ) &
      probe_pids+=($!)
    fi
  done <<<"$serve_status"

  if ((${#probe_pids[@]})); then
    for pid in "${probe_pids[@]}"; do
      wait "$pid" || true
    done
  fi

  for i in "${!probe_svc[@]}"; do
    res=""
    if [[ -r "$TMP_DIR/probe.$((i + 1))" ]]; then
      read -r res <"$TMP_DIR/probe.$((i + 1))"
    fi
    if [[ "$res" == "green" ]]; then
      tdot=$green
    else
      tdot=$red
    fi
    ts_lines+=("$(printf '  %s %-14s %-6s %s' "$tdot" "${probe_svc[$i]}" "${probe_port[$i]}" "${probe_url[$i]}")")
  done
fi

if ((${#ts_lines[@]})); then
  printf '\ntailscale serve\n'
  printf '%s\n' "${ts_lines[@]}" | awk '!seen[$0]++'
fi
