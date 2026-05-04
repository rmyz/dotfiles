#!/usr/bin/env bash
set -euo pipefail

mkdir -p "$HOME/.config"
ln -sfn "$PWD/starship.toml" "$HOME/.config/starship.toml"
