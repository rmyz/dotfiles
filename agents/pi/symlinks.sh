#!/usr/bin/env bash
set -euo pipefail

target="$HOME/.pi/agent"
mkdir -p "$target"
ln -sfn "$(dirname "$PWD")/AGENTS.md" "$target/AGENTS.md"
