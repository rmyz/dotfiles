#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.." && cd "$(pwd -P)"
printf '%s%s\n' "$(git log -1 --format=%h -- . ../../AGENTS.md ../../REVIEW.md ../cross-review ../technical-review ../product-review)" \
  "$(git diff --quiet HEAD -- . ../../AGENTS.md ../../REVIEW.md ../cross-review ../technical-review ../product-review || echo -dirty)"
