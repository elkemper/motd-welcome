#!/usr/bin/env bash
set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
renderer="$here/motd-welcome.sh"
checker="$here/motd-welcome-update-check.sh"
real_timeout=$(command -v timeout)

command -v jq >/dev/null 2>&1 || { printf 'jq is required\n' >&2; exit 1; }
[[ -x "$renderer" ]] || { printf 'missing %s\n' "$renderer" >&2; exit 1; }
[[ -x "$checker" ]] || { printf 'missing %s\n' "$checker" >&2; exit 1; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin"
export FIX="$tmp"
export REAL_TIMEOUT="$real_timeout"

fail() { printf 'not ok - %s\n' "$*" >&2; exit 1; }
ok() { printf 'ok - %s\n' "$*"; }

assert_contains() {
  local haystack="$1" needle="$2" msg="$3"
  [[ "$haystack" == *"$needle"* ]] || fail "$msg (missing: $needle)"
}

assert_not_contains() {
  local haystack="$1" needle="$2" msg="$3"
  [[ "$haystack" != *"$needle"* ]] || fail "$msg (unexpected: $needle)"
}

line_of() {
  printf '%s\n' "$1" | grep -F "● $2 " | head -n1 || true
}

cat > "$FIX/ids.txt" <<'IDS'
0dc8f22d7f07
201255379175
36aa4512922f
84ed8db46e7b
548f478bd3a1
07ce2908b5ad
dcaff08faaba
72367768331b
eba9ec299e8a
e4ccfc4bf4d2
47526b77bdb8
c84d1cdf0064
2541597ac331
e1c7a2ca047a
6b30d11e418d
74e03af7973e
IDS

cat > "$FIX/stats.tsv" <<'STATS'
0dc8f22d7f07	0.07%	175.1MiB / 12GiB
201255379175	0.06%	136.2MiB / 12GiB
36aa4512922f	0.05%	162.4MiB / 12GiB
84ed8db46e7b	0.08%	277.8MiB / 12GiB
548f478bd3a1	3.12%	203.9MiB / 12GiB
07ce2908b5ad	0.01%	369.7MiB / 12GiB
dcaff08faaba	0.01%	179.3MiB / 12GiB
72367768331b	0.12%	227.6MiB / 12GiB
eba9ec299e8a	0.00%	42.38MiB / 12GiB
e4ccfc4bf4d2	0.06%	37.93MiB / 12GiB
47526b77bdb8	0.19%	325.6MiB / 12GiB
c84d1cdf0064	0.02%	28.21MiB / 12GiB
2541597ac331	0.07%	181.2MiB / 12GiB
e1c7a2ca047a	0.00%	50.23MiB / 12GiB
6b30d11e418d	0.00%	488KiB / 12GiB
74e03af7973e	0.11%	115.5MiB / 12GiB
STATS

cat > "$FIX/inspect.json" <<'INSPECT'
[
  {
    "Id": "0dc8f22d7f072cd685beba887d1ca228d71a0f3b5606efdf974b81018afd771c",
    "Name": "/radarr",
    "Config": {
      "Image": "lscr.io/linuxserver/radarr:latest",
      "ExposedPorts": {
        "7878/tcp": {}
      }
    },
    "State": {
      "Status": "running",
      "StartedAt": "2026-01-01T00:00:00.000000000Z",
      "Health": null
    },
    "NetworkSettings": {
      "Ports": {
        "7878/tcp": [
          {
            "HostIp": "0.0.0.0",
            "HostPort": "7878"
          },
          {
            "HostIp": "::",
            "HostPort": "7878"
          }
        ]
      }
    }
  },
  {
    "Id": "201255379175636a9d8996b54b85f4d738e5b78e61870cf8cc630d505f274ad6",
    "Name": "/lidarr_ru",
    "Config": {
      "Image": "lscr.io/linuxserver/lidarr:latest",
      "ExposedPorts": {
        "8686/tcp": {}
      }
    },
    "State": {
      "Status": "running",
      "StartedAt": "2026-01-01T00:00:00.000000000Z",
      "Health": null
    },
    "NetworkSettings": {
      "Ports": {
        "8686/tcp": [
          {
            "HostIp": "0.0.0.0",
            "HostPort": "8687"
          },
          {
            "HostIp": "::",
            "HostPort": "8687"
          }
        ]
      }
    }
  },
  {
    "Id": "36aa4512922faf45d9c2fb9066ff2dec72c627c2afe5dd1b6d06329f515e19ac",
    "Name": "/lidarr",
    "Config": {
      "Image": "lscr.io/linuxserver/lidarr:latest",
      "ExposedPorts": {
        "8686/tcp": {}
      }
    },
    "State": {
      "Status": "running",
      "StartedAt": "2026-01-01T00:00:00.000000000Z",
      "Health": null
    },
    "NetworkSettings": {
      "Ports": {
        "8686/tcp": [
          {
            "HostIp": "0.0.0.0",
            "HostPort": "8686"
          },
          {
            "HostIp": "::",
            "HostPort": "8686"
          }
        ]
      }
    }
  },
  {
    "Id": "84ed8db46e7bedbc6d325e89e4ad6c7476a0a0560755a5c18cf0a9627644b55e",
    "Name": "/sonarr",
    "Config": {
      "Image": "lscr.io/linuxserver/sonarr:latest",
      "ExposedPorts": {
        "8989/tcp": {}
      }
    },
    "State": {
      "Status": "running",
      "StartedAt": "2026-01-01T00:00:00.000000000Z",
      "Health": null
    },
    "NetworkSettings": {
      "Ports": {
        "8989/tcp": [
          {
            "HostIp": "0.0.0.0",
            "HostPort": "8989"
          },
          {
            "HostIp": "::",
            "HostPort": "8989"
          }
        ]
      }
    }
  },
  {
    "Id": "548f478bd3a17cf1dbb6bebc9c5885a29b750611a9881af831125a4db2739fb5",
    "Name": "/qbittorrent",
    "Config": {
      "Image": "linuxserver/qbittorrent:latest",
      "ExposedPorts": {
        "6881/tcp": {},
        "6881/udp": {},
        "8080/tcp": {},
        "9092/tcp": {}
      }
    },
    "State": {
      "Status": "running",
      "StartedAt": "2026-01-01T00:00:00.000000000Z",
      "Health": null
    },
    "NetworkSettings": {
      "Ports": {
        "6881/tcp": [
          {
            "HostIp": "0.0.0.0",
            "HostPort": "6881"
          },
          {
            "HostIp": "::",
            "HostPort": "6881"
          }
        ],
        "6881/udp": [
          {
            "HostIp": "0.0.0.0",
            "HostPort": "6881"
          },
          {
            "HostIp": "::",
            "HostPort": "6881"
          }
        ],
        "8080/tcp": null,
        "9092/tcp": [
          {
            "HostIp": "0.0.0.0",
            "HostPort": "9092"
          },
          {
            "HostIp": "::",
            "HostPort": "9092"
          }
        ]
      }
    }
  },
  {
    "Id": "07ce2908b5ad9509c3b50283ea981942dddf28d46b560d39490dfd7048685bd5",
    "Name": "/flaresolverr",
    "Config": {
      "Image": "ghcr.io/flaresolverr/flaresolverr:latest",
      "ExposedPorts": {
        "8191/tcp": {},
        "8192/tcp": {}
      }
    },
    "State": {
      "Status": "running",
      "StartedAt": "2026-01-01T00:00:00.000000000Z",
      "Health": null
    },
    "NetworkSettings": {
      "Ports": {
        "8191/tcp": null,
        "8192/tcp": null
      }
    }
  },
  {
    "Id": "dcaff08faaba91c3dd6865484cf6f6c9166d40764814746ce6b1b4eccb439220",
    "Name": "/jackett",
    "Config": {
      "Image": "lscr.io/linuxserver/jackett:latest",
      "ExposedPorts": {
        "9117/tcp": {}
      }
    },
    "State": {
      "Status": "running",
      "StartedAt": "2026-01-01T00:00:00.000000000Z",
      "Health": null
    },
    "NetworkSettings": {
      "Ports": {
        "9117/tcp": [
          {
            "HostIp": "0.0.0.0",
            "HostPort": "9117"
          },
          {
            "HostIp": "::",
            "HostPort": "9117"
          }
        ]
      }
    }
  },
  {
    "Id": "72367768331ba741b23cc16cf8ed8f57a9a548fa5181aa3d342597a00bdf9f13",
    "Name": "/bazarr",
    "Config": {
      "Image": "lscr.io/linuxserver/bazarr:latest",
      "ExposedPorts": {
        "6767/tcp": {}
      }
    },
    "State": {
      "Status": "running",
      "StartedAt": "2026-01-01T00:00:00.000000000Z",
      "Health": null
    },
    "NetworkSettings": {
      "Ports": {
        "6767/tcp": [
          {
            "HostIp": "0.0.0.0",
            "HostPort": "6767"
          },
          {
            "HostIp": "::",
            "HostPort": "6767"
          }
        ]
      }
    }
  },
  {
    "Id": "eba9ec299e8a3b88ee8b9b56209d90af1cdcd63a5376bedc02cfd652428f1400",
    "Name": "/vaultwarden",
    "Config": {
      "Image": "vaultwarden/server:latest",
      "ExposedPorts": {
        "80/tcp": {}
      }
    },
    "State": {
      "Status": "running",
      "StartedAt": "2026-01-01T00:00:00.000000000Z",
      "Health": {
        "Status": "healthy",
        "FailingStreak": 0,
        "Log": [
          {
            "Start": "2026-11-02T14:48:48.855500423Z",
            "End": "2026-11-02T14:48:48.917637003Z",
            "ExitCode": 0,
            "Output": "\"2026-11-02T14:48:48.916065Z\""
          },
          {
            "Start": "2026-11-02T14:49:48.918593345Z",
            "End": "2026-11-02T14:49:48.978302554Z",
            "ExitCode": 0,
            "Output": "\"2026-11-02T14:49:48.976785Z\""
          },
          {
            "Start": "2026-11-02T14:50:48.979731818Z",
            "End": "2026-11-02T14:50:49.041280061Z",
            "ExitCode": 0,
            "Output": "\"2026-11-02T14:50:49.039449Z\""
          },
          {
            "Start": "2026-11-02T14:51:49.042467128Z",
            "End": "2026-11-02T14:51:49.102530629Z",
            "ExitCode": 0,
            "Output": "\"2026-11-02T14:51:49.101165Z\""
          },
          {
            "Start": "2026-11-02T14:52:49.103045428Z",
            "End": "2026-11-02T14:52:49.165396732Z",
            "ExitCode": 0,
            "Output": "\"2026-11-02T14:52:49.163861Z\""
          }
        ]
      }
    },
    "NetworkSettings": {
      "Ports": {}
    }
  },
  {
    "Id": "e4ccfc4bf4d295a46b805be64358fd5054b5fd45cd2d7fb913db9b32e05399f8",
    "Name": "/ts-vaultwarden",
    "Config": {
      "Image": "tailscale/tailscale:latest",
      "ExposedPorts": null
    },
    "State": {
      "Status": "running",
      "StartedAt": "2026-01-01T00:00:00.000000000Z",
      "Health": null
    },
    "NetworkSettings": {
      "Ports": {}
    }
  },
  {
    "Id": "47526b77bdb85d1a05787a72a4e2a233c61dbb718e51cfb0bc1350dcf4fba786",
    "Name": "/plex",
    "Config": {
      "Image": "lscr.io/linuxserver/plex:latest",
      "ExposedPorts": {
        "1900/udp": {},
        "32400/tcp": {},
        "32410/udp": {},
        "32412/udp": {},
        "32413/udp": {},
        "32414/udp": {},
        "32469/tcp": {},
        "5353/udp": {},
        "8324/tcp": {}
      }
    },
    "State": {
      "Status": "running",
      "StartedAt": "2026-01-01T00:00:00.000000000Z",
      "Health": null
    },
    "NetworkSettings": {
      "Ports": {}
    }
  },
  {
    "Id": "c84d1cdf0064580b0abdb187345057a2c1e942f9f331ad8d54597161e7c0bca5",
    "Name": "/ts-plex",
    "Config": {
      "Image": "tailscale/tailscale:latest",
      "ExposedPorts": null
    },
    "State": {
      "Status": "running",
      "StartedAt": "2026-01-01T00:00:00.000000000Z",
      "Health": null
    },
    "NetworkSettings": {
      "Ports": {}
    }
  },
  {
    "Id": "2541597ac3314833fc9e7b82215569b3162190dec1f978f100d23f12d8ce67a5",
    "Name": "/ersatztv",
    "Config": {
      "Image": "ghcr.io/ersatztv/legacy",
      "ExposedPorts": {
        "8409/tcp": {}
      }
    },
    "State": {
      "Status": "running",
      "StartedAt": "2026-01-01T00:00:00.000000000Z",
      "Health": null
    },
    "NetworkSettings": {
      "Ports": {
        "8409/tcp": [
          {
            "HostIp": "0.0.0.0",
            "HostPort": "8409"
          },
          {
            "HostIp": "::",
            "HostPort": "8409"
          }
        ]
      }
    }
  },
  {
    "Id": "e1c7a2ca047a0bb9d5fad14eac68e260a3c1ea91e76107800976d2dd6ef58d03",
    "Name": "/app-homelab-lib-1",
    "Config": {
      "Image": "exampleuser/homelab-lib:latest",
      "ExposedPorts": {
        "3214/tcp": {}
      }
    },
    "State": {
      "Status": "running",
      "StartedAt": "2026-01-01T00:00:00.000000000Z",
      "Health": {
        "Status": "healthy",
        "FailingStreak": 0,
        "Log": [
          {
            "Start": "2026-11-02T14:52:26.552635946Z",
            "End": "2026-11-02T14:52:26.609726245Z",
            "ExitCode": 0,
            "Output": "{\"success\":true}"
          },
          {
            "Start": "2026-11-02T14:52:36.610179413Z",
            "End": "2026-11-02T14:52:36.66904477Z",
            "ExitCode": 0,
            "Output": "{\"success\":true}"
          },
          {
            "Start": "2026-11-02T14:52:46.669869297Z",
            "End": "2026-11-02T14:52:46.733145038Z",
            "ExitCode": 0,
            "Output": "{\"success\":true}"
          },
          {
            "Start": "2026-11-02T14:52:56.734158378Z",
            "End": "2026-11-02T14:52:56.79216994Z",
            "ExitCode": 0,
            "Output": "{\"success\":true}"
          },
          {
            "Start": "2026-11-02T14:53:06.793238846Z",
            "End": "2026-11-02T14:53:06.851529354Z",
            "ExitCode": 0,
            "Output": "{\"success\":true}"
          }
        ]
      }
    },
    "NetworkSettings": {
      "Ports": {
        "3214/tcp": [
          {
            "HostIp": "0.0.0.0",
            "HostPort": "3214"
          },
          {
            "HostIp": "::",
            "HostPort": "3214"
          }
        ]
      }
    }
  },
  {
    "Id": "6b30d11e418d07421449253246ee3037dc84ac7878111cd9e3d1ce00ab1ed8d3",
    "Name": "/ffmpeg-vaapi",
    "Config": {
      "Image": "jrottenberg/ffmpeg:7-vaapi",
      "ExposedPorts": null
    },
    "State": {
      "Status": "running",
      "StartedAt": "2026-01-01T00:00:00.000000000Z",
      "Health": null
    },
    "NetworkSettings": {
      "Ports": {}
    }
  },
  {
    "Id": "74e03af7973e2bdbce25bc952af8bee2c1f3d14c30c638dc5e3c34bfa38be2ea",
    "Name": "/n8n-n8n-1",
    "Config": {
      "Image": "n8nio/n8n:latest",
      "ExposedPorts": {
        "5678/tcp": {},
        "5878/tcp": {}
      }
    },
    "State": {
      "Status": "running",
      "StartedAt": "2026-01-01T00:00:00.000000000Z",
      "Health": null
    },
    "NetworkSettings": {
      "Ports": {
        "5678/tcp": null,
        "5878/tcp": [
          {
            "HostIp": "0.0.0.0",
            "HostPort": "5878"
          },
          {
            "HostIp": "::",
            "HostPort": "5878"
          }
        ]
      }
    }
  }
]
INSPECT

cat > "$FIX/image-inspect.json" <<'IMAGE'
[
  {
    "RepoTags": [
      "exampleuser/homelab-lib:latest"
    ],
    "RepoDigests": [
      "exampleuser/homelab-lib@sha256:6337612fb0ca0845447099943a718feada6e4716b5a7175e8e384da6f14e55ae"
    ]
  },
  {
    "RepoTags": [
      "ghcr.io/ersatztv/legacy:latest"
    ],
    "RepoDigests": [
      "ghcr.io/ersatztv/legacy@sha256:9cea634772e8f53eb6e16214763ca7f08cd65d128ac64eb908513d204735b87b"
    ]
  },
  {
    "RepoTags": [
      "ghcr.io/flaresolverr/flaresolverr:latest"
    ],
    "RepoDigests": [
      "ghcr.io/flaresolverr/flaresolverr@sha256:0f04a03953eca3d2638519ca86e49729b67eeca1a326dda8fc9da5dec4368cd6"
    ]
  },
  {
    "RepoTags": [
      "jrottenberg/ffmpeg:7-vaapi"
    ],
    "RepoDigests": [
      "jrottenberg/ffmpeg@sha256:96eb030e42ded5972c008880de87e7f9b5a7b4d44b7820327d1ffdfaa557fe52"
    ]
  },
  {
    "RepoTags": [
      "linuxserver/qbittorrent:latest"
    ],
    "RepoDigests": [
      "linuxserver/qbittorrent@sha256:a89aaa6de9871a4205c50d5b118b51eb08e63925d2d7c66df5afb9623755f642"
    ]
  },
  {
    "RepoTags": [
      "lscr.io/linuxserver/bazarr:latest"
    ],
    "RepoDigests": [
      "lscr.io/linuxserver/bazarr@sha256:ef1e87f6ffceae7c37835cb6234b67fe850bac07e24c2cc21d9dd3d742bcf6e5"
    ]
  },
  {
    "RepoTags": [
      "lscr.io/linuxserver/jackett:latest"
    ],
    "RepoDigests": [
      "lscr.io/linuxserver/jackett@sha256:d981f50f7cc6f3cf764c752d13b025df4d9813bcc839e455d6c346d6955f509d"
    ]
  },
  {
    "RepoTags": [
      "lscr.io/linuxserver/lidarr:latest"
    ],
    "RepoDigests": [
      "lscr.io/linuxserver/lidarr@sha256:a602cde7f9c643f15442e9ce59e87bdb77b984286b30761ec7345fb1f5eb97a9"
    ]
  },
  {
    "RepoTags": [
      "lscr.io/linuxserver/plex:latest"
    ],
    "RepoDigests": [
      "lscr.io/linuxserver/plex@sha256:1d0c26291d72041875ef585656e511f71ea4b30f0346348f49a1854d727d315a"
    ]
  },
  {
    "RepoTags": [
      "lscr.io/linuxserver/radarr:latest"
    ],
    "RepoDigests": [
      "lscr.io/linuxserver/radarr@sha256:283c794142078cf7d03287d8929647f76f9c035f29e12681d3f958616cbfb6c1"
    ]
  },
  {
    "RepoTags": [
      "lscr.io/linuxserver/sonarr:latest"
    ],
    "RepoDigests": [
      "lscr.io/linuxserver/sonarr@sha256:b994b08127589a4e3e63eec3a4989ddc1d8c045e5b2d591b406b236b034d3d63"
    ]
  },
  {
    "RepoTags": [
      "n8nio/n8n:latest"
    ],
    "RepoDigests": [
      "n8nio/n8n@sha256:4167bb2eb8d839b7dc2cfa08bbaced04df49eea9797cb3c8528dabc0e8b826d5"
    ]
  },
  {
    "RepoTags": [
      "tailscale/tailscale:latest"
    ],
    "RepoDigests": [
      "tailscale/tailscale@sha256:ea97c482f606da28baa1e7fc001507a612dac86365f6713f5373f078cea89daf"
    ]
  },
  {
    "RepoTags": [
      "vaultwarden/server:latest"
    ],
    "RepoDigests": [
      "vaultwarden/server@sha256:605f85d065f36f67acb8d4692d5bd32e1f3ad1d6d0e631d9475aba7cb985d182"
    ]
  }
]
IMAGE

cat > "$FIX/tailscale.txt" <<'TAILSCALE'
https://books.tailnet.example.ts.net (tailnet only) (svc:books)
|-- / proxy http://localhost:3214

https://qbit.tailnet.example.ts.net (tailnet only) (svc:qbit)
|-- / proxy http://localhost:9092
TAILSCALE

cat > "$FIX/bin/docker" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
case "${1:-}" in
  ps)
    cat "$FIX/ids.txt"
    ;;
  inspect)
    if [[ "${2:-}" == "--format" ]]; then
      shift 3
      for id in "$@"; do
        jq -r --arg id "$id" '.[] | select(.Id | startswith($id)) | .Config.Image' "$FIX/inspect.json"
      done
    else
      cat "$FIX/inspect.json"
    fi
    ;;
  stats)
    cat "$FIX/stats.tsv"
    ;;
  image)
    cat "$FIX/image-inspect.json"
    ;;
  *)
    exit 1
    ;;
esac
STUB

cat > "$FIX/bin/regctl" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
[[ "${1:-} ${2:-}" == "image digest" ]] || exit 1
img="${3:-}"
awk -F'\t' -v img="$img" '$1 == img { print $2; found=1; exit } END { exit found ? 0 : 1 }' "$FIX/remote.tsv"
STUB

cat > "$FIX/bin/tailscale" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
[[ "${1:-}" == "serve" && "${2:-}" == "status" ]] || exit 1
cat "$FIX/tailscale.txt"
STUB

cat > "$FIX/bin/systemctl" <<'STUB'
#!/usr/bin/env bash
exit 0
STUB

cat > "$FIX/bin/hostname" <<'STUB'
#!/usr/bin/env bash
case "${1:-}" in
  -I) printf '192.0.2.10\n' ;;
  *) printf 'testhost\n' ;;
esac
STUB

cat > "$FIX/bin/timeout" <<'STUB'
#!/usr/bin/env bash
for a in "$@"; do
  [[ "$a" == *"/dev/tcp/"* ]] && exit 0
done
exec "$REAL_TIMEOUT" "$@"
STUB

chmod +x "$FIX/bin/"*

jq -R -r -n --slurpfile imgs "$FIX/image-inspect.json" '
  [inputs | select(length > 0)] as $refs |
  $refs[] as $r |
  ($imgs[0][] | select(((.RepoTags // []) | index($r)) or ((.RepoTags // []) | index($r + ":latest")))) as $i |
  [$r, (($i.RepoDigests[0] // "") | sub("^[^@]+@"; ""))] | @tsv
' < <(jq -r '[.[].Config.Image] | unique[]' "$FIX/inspect.json") > "$FIX/local.tsv"

fake_sonarr="sha256:$(printf '%064d' 1)"
fake_plex="sha256:$(printf '%064d' 2)"
fake_n8n="sha256:$(printf '%064d' 3)"

awk -F'\t' -v OFS='\t' -v s="$fake_sonarr" -v p="$fake_plex" -v n="$fake_n8n" '
  $1 == "lscr.io/linuxserver/sonarr:latest" { $2 = s; print; next }
  $1 == "lscr.io/linuxserver/plex:latest"   { $2 = p; print; next }
  $1 == "n8nio/n8n:latest"                  { $2 = n; print; next }
  $1 == "exampleuser/homelab-lib:latest"       { next }
  { print }
' "$FIX/local.tsv" > "$FIX/remote.tsv"

{
  printf '{"checked_at":"2026-11-02T12:00:00Z","images":{'
  first=1
  while IFS=$'\t' read -r img dig; do
    if [[ "$first" -eq 0 ]]; then printf ','; fi
    printf '"%s":{"digests":["%s"]}' "$img" "$dig"
    first=0
  done < "$FIX/remote.tsv"
  printf '}}\n'
} > "$FIX/cache.json"

jq empty "$FIX/cache.json" || fail "embedded cache is invalid"

export PATH="$FIX/bin:$PATH"

out=$(MOTD_WELCOME_CACHE="$FIX/cache.json" "$renderer")
clean=$(printf '%s\n' "$out" | sed 's/\x1b\[[0-9;]*m//g')

assert_contains "$clean" "testhost | 192.0.2.10" "banner host/ip"
assert_contains "$clean" "tailscale serve" "tailscale header"

plex=$(line_of "$clean" plex)
assert_contains "$plex" "32400 +2" "plex ports"
assert_contains "$plex" "↑ new" "plex update"

sonarr=$(line_of "$clean" sonarr)
assert_contains "$sonarr" "8989" "sonarr port"
assert_contains "$sonarr" "↑ new" "sonarr update"

n8n=$(line_of "$clean" n8n-n8n-1)
assert_contains "$n8n" "5878" "n8n port"
assert_contains "$n8n" "↑ new" "n8n update"

radarr=$(line_of "$clean" radarr)
assert_contains "$radarr" "7878" "radarr port"
assert_not_contains "$radarr" "↑ new" "radarr no update"

qbit=$(line_of "$clean" qbittorrent)
assert_contains "$qbit" "6881 +1" "qbittorrent ports"
assert_not_contains "$qbit" "↑ new" "qbittorrent no update"

flaresolverr=$(line_of "$clean" flaresolverr)
assert_contains "$flaresolverr" "8191 +1" "flaresolverr exposed ports"

vaultwarden=$(line_of "$clean" vaultwarden)
assert_contains "$vaultwarden" " 80 " "vaultwarden port"

ffmpeg=$(line_of "$clean" ffmpeg-vaapi)
assert_contains "$ffmpeg" "—" "ffmpeg no port"

ts_plex=$(line_of "$clean" ts-plex)
assert_contains "$ts_plex" "—" "ts-plex no port"

lidarr_ru=$(line_of "$clean" lidarr_ru)
assert_contains "$lidarr_ru" "8687" "lidarr_ru mapped port"

lib=$(line_of "$clean" app-homelab-lib-1)
assert_contains "$lib" "3214" "homelab-lib port"

ersatz=$(line_of "$clean" ersatztv)
assert_contains "$ersatz" "8409" "ersatztv port"

updates=$(printf '%s\n' "$clean" | grep -c '↑ new' || true)
[[ "$updates" -eq 3 ]] || fail "expected 3 updates, got $updates"

books=$(printf '%s\n' "$clean" | grep -F 'books' | grep -F '3214' | head -n1 || true)
assert_contains "$books" "https://books.tailnet.example.ts.net" "books url"
qbit_ts=$(printf '%s\n' "$clean" | grep -F 'qbit' | grep -F '9092' | head -n1 || true)
assert_contains "$qbit_ts" "https://qbit.tailnet.example.ts.net" "qbit url"
assert_contains "$out" $'\033[32m●\033[0m books' "books reachable"

nocache=$(MOTD_WELCOME_CACHE="$FIX/none.json" "$renderer")
cleannc=$(printf '%s\n' "$nocache" | sed 's/\x1b\[[0-9;]*m//g')
assert_not_contains "$cleannc" "↑ new" "no updates without cache"

mkdir -p "$FIX/cache"
printf '{"checked_at":"2000-01-01T00:00:00Z","images":{"stale/image:latest":{"digests":["sha256:dead"]}}}\n' \
  > "$FIX/cache/images.json"

MOTD_WELCOME_CACHE_DIR="$FIX/cache" "$checker"

cache="$FIX/cache/images.json"
jq empty "$cache" || fail "generated cache is invalid json"
[[ "$(stat -c %a "$cache")" == "644" ]] || fail "cache mode is not 644"
jq -e '.images | length == 14' "$cache" >/dev/null || fail "cache key count"
jq -e '.images | has("stale/image:latest") | not' "$cache" >/dev/null || fail "stale key not pruned"
jq -e '.images["exampleuser/homelab-lib:latest"].digests == []' "$cache" >/dev/null \
  || fail "local image digest is not empty"
jq -e '.checked_at | test("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$")' "$cache" >/dev/null \
  || fail "checked_at format"

for img in "lscr.io/linuxserver/radarr:latest" "lscr.io/linuxserver/sonarr:latest" "n8nio/n8n:latest"; do
  expected=$(awk -F'\t' -v i="$img" '$1 == i { print $2 }' "$FIX/remote.tsv")
  actual=$(jq -r --arg i "$img" '.images[$i].digests[0] // ""' "$cache")
  [[ "$actual" == "$expected" ]] || fail "digest for $img"
done

ok "renderer"
ok "missing cache"
ok "update-check"
