#!/usr/bin/env bash
set -uo pipefail

CACHE_FILE="${MOTD_WELCOME_CACHE:-/var/cache/motd-welcome/images.json}"
NOW=$(date +%s)

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

if ! ids=$(docker ps -q 2>/dev/null); then
  printf 'docker: cannot query containers\n'
  exit 0
fi

if [[ -z "$ids" ]]; then
  printf 'no running containers\n'
  exit 0
fi

mapfile -t cids <<<"$ids"
containers=$(docker inspect "${cids[@]}" 2>/dev/null) || exit 0

declare -A CPU MEM
while IFS=$'\t' read -r cid cpu mem; do
  [[ -z "$cid" ]] && continue
  CPU["${cid:0:12}"]="${cpu:-}"
  MEM["${cid:0:12}"]="${mem%% /*}"
done < <(timeout 3 docker stats --no-stream --format $'{{.ID}}\t{{.CPUPerc}}\t{{.MemUsage}}' 2>/dev/null)

mapfile -t image_refs < <(jq -r '.[].Config.Image // empty' <<<"$containers" | sort -u)
image_map='{}'
if ((${#image_refs[@]})); then
  image_map=$(docker image inspect "${image_refs[@]}" 2>/dev/null | jq -c '
    [ .[] as $i |
      (($i.RepoDigests // []) | map(sub("^[^@]+@"; ""))) as $d |
      ($i.RepoTags // [])[] as $t |
      {key: $t, value: $d},
      (if ($t | endswith(":latest")) then {key: ($t | sub(":latest$"; "")), value: $d} else empty end)
    ] | from_entries
  ' 2>/dev/null)
  [[ -z "$image_map" ]] && image_map='{}'
fi

if [[ ! -r "$CACHE_FILE" ]]; then
  (systemctl start motd-welcome-update-check.service >/dev/null 2>&1 &)
fi

while IFS='|' read -r id name image status health started ports exposed_tcp exposed_any; do
  [[ -z "$name" ]] && continue

  if [[ "$status" != "running" || "$health" == "unhealthy" ]]; then
    dot=$red
  elif [[ "$health" == "starting" ]]; then
    dot=$yellow
  else
    dot=$green
  fi

  if [[ "$status" == "running" && -n "$started" ]]; then
    _s=${started%%.*}
    [[ "$_s" != *Z ]] && _s="${_s}Z"
    if _st=$(date -d "$_s" +%s 2>/dev/null); then
      up=$(human_duration $((NOW - _st)))
    else
      up="—"
    fi
  else
    up="—"
  fi

  ports_field="—"
  _port_list=""
  _port_sort=""
  if [[ -n "$ports" ]]; then
    _port_list=$ports
    _port_sort="-n"
  elif [[ -n "$exposed_tcp" ]]; then
    _port_list=$exposed_tcp
  elif [[ -n "$exposed_any" ]]; then
    _port_list=$exposed_any
  fi
  if [[ -n "$_port_list" ]]; then
    mapfile -t _ports < <(tr ',' '\n' <<<"$_port_list" | sed '/^$/d' | sort $_port_sort -u)
    if ((${#_ports[@]} > 0)); then
      ports_field="${_ports[0]}"
      ((${#_ports[@]} > 1)) && ports_field+=" +$((${#_ports[@]} - 1))"
    fi
  fi

  short="${id:0:12}"
  cpu="${CPU[$short]:-—}"
  mem="${MEM[$short]:-—}"
  [[ -z "$cpu" ]] && cpu="—"
  [[ -z "$mem" ]] && mem="—"

  update=""
  if [[ -r "$CACHE_FILE" ]]; then
    mapfile -t _local < <(jq -r --arg ref "$image" '.[$ref] // [] | .[]' <<<"$image_map" 2>/dev/null)
    mapfile -t _remote < <(jq -r --arg ref "$image" '.images[$ref].digests // [] | .[]' "$CACHE_FILE" 2>/dev/null)
    if ((${#_local[@]} > 0 && ${#_remote[@]} > 0)); then
      _common=$(comm -12 <(printf '%s\n' "${_local[@]}" | sort -u) <(printf '%s\n' "${_remote[@]}" | sort -u))
      [[ -z "$_common" ]] && update="↑ new"
    fi
  fi

  printf '  %s %-18s %-10s %-9s %7s %7s  %s\n' "$dot" "$name" "$ports_field" "$up" "$cpu" "$mem" "$update"
done < <(jq -r '
  sort_by(.Name)[] |
  [
    .Id,
    (.Name | ltrimstr("/")),
    (.Config.Image // ""),
    (.State.Status // ""),
    (.State.Health.Status // ""),
    (.State.StartedAt // ""),
    ([ (.NetworkSettings.Ports // {}) | to_entries[] | select(.key | endswith("/tcp")) | .value // [] | .[] | .HostPort // empty ] | unique | join(",")),
    ([ (.Config.ExposedPorts // {}) | keys[] | select(endswith("/tcp")) | sub("/tcp$"; "") ] | join(",")),
    ([ (.Config.ExposedPorts // {}) | keys[] | sub("/[a-z]+$"; "") ] | join(","))
  ] | join("|")
' <<<"$containers")

tcp_open() {
  local host="$1" port="$2"
  [[ "$port" =~ ^[0-9]+$ ]] || return 1
  timeout 1 bash -c "exec 3<>/dev/tcp/$host/$port" 2>/dev/null
}

ts_lines=()
if command -v tailscale >/dev/null 2>&1; then
  serve_status=$(timeout 3 tailscale serve status 2>/dev/null || true)
  url=""
  svc=""
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
      if tcp_open "$thost" "$tport"; then
        tdot=$green
      else
        tdot=$red
      fi
      ts_lines+=("$(printf '  %s %-14s %-6s %s' "$tdot" "$svc" "$tport" "$url")")
    fi
  done <<<"$serve_status"
fi

if ((${#ts_lines[@]})); then
  printf '\ntailscale serve\n'
  printf '%s\n' "${ts_lines[@]}" | awk '!seen[$0]++'
fi
