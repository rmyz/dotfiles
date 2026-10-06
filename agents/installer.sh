#!/usr/bin/env bash
set -euo pipefail

for dir in */; do
  if [ -x "$dir/installer.sh" ]; then
    ( cd "$dir" && ./installer.sh )
  fi
done
