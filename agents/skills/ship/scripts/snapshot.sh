#!/bin/sh
set -eu

GIT_INDEX_FILE=$(mktemp -u)
export GIT_INDEX_FILE
trap 'rm -f "$GIT_INDEX_FILE"' EXIT

git read-tree HEAD
git add -A
git commit-tree "$(git write-tree)" -p HEAD -m snapshot
