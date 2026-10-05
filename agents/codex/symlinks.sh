#!/usr/bin/env bash
set -euo pipefail

target="$HOME/.codex"
mkdir -p "$target"
ln -sfn "$(dirname "$PWD")/AGENTS.md" "$target/AGENTS.md"
