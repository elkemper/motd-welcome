#!/usr/bin/env bash

test_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
src_dir="$test_root/src"
renderer="$src_dir/motd-welcome.sh"
checker="$src_dir/motd-welcome-update-check.sh"
collector="$src_dir/motd-welcome-stats.sh"
installer="$test_root/install.sh"
uninstaller="$test_root/uninstall.sh"

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
