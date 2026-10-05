#!/usr/bin/env bash
set -euo pipefail

target="$HOME/.cursor"
mkdir -p "$target/rules"
ln -sfn "$(dirname "$PWD")/AGENTS.md" "$target/rules/agents.mdc"
