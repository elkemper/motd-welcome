#!/usr/bin/env bash
set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

for test_file in "$here"/*.test.sh; do
  printf '== %s ==\n' "$(basename "$test_file")"
  "$test_file"
done
