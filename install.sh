#!/usr/bin/env bash
set -euo pipefail

# Install xcode-select if missing
if ! xcode-select -p >/dev/null 2>&1; then
  echo "Installing xcode-select..."
  xcode-select --install
fi

# Run installers and symlinks in a fixed order.
# brew runs first because everything else may depend on its packages.
folders=(brew mac git zsh starship-prompt agent-skills raycast)

for folder in "${folders[@]}"; do
  if [ ! -d "$folder" ]; then
    continue
  fi

  if [ -x "$folder/installer.sh" ]; then
    echo "Executing $folder's installer..."
    ( cd "$folder" && ./installer.sh )
  fi

  if [ -x "$folder/symlinks.sh" ]; then
    echo "Executing $folder's symlinks..."
    ( cd "$folder" && ./symlinks.sh )
  fi
done

echo "rmyz dotfiles loaded successfully"
