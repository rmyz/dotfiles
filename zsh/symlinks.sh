#!/usr/bin/env bash
set -euo pipefail

ln -sfn "$PWD/.zshrc" "$HOME/.zshrc"

# .zshrc.work.sh is gitignored and local-only; symlink only if it exists.
if [ -f "$PWD/.zshrc.work.sh" ]; then
  ln -sfn "$PWD/.zshrc.work.sh" "$HOME/.zshrc.work.sh"
fi
