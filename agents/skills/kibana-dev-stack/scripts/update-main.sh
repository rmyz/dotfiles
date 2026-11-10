#!/usr/bin/env bash
set -euo pipefail

MAIN=$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")
cd "$MAIN"

if [ "$(git branch --show-current)" != main ] || [ -n "$(git status --porcelain)" ]; then
  echo "skip: primary checkout is not on a clean main"
  exit 0
fi

git fetch upstream main
git merge --ff-only upstream/main
zsh -ic 'kbnb'

if codegraph status "$MAIN" --json | jq -e '.index.reindexRecommended' >/dev/null; then
  codegraph index "$MAIN"
else
  codegraph sync "$MAIN"
fi
