#!/usr/bin/env bash
set -euo pipefail

## install brew
NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

## install git
brew install git

## clone repo
git clone https://github.com/rmyz/dotfiles.git .dotfiles

cd .dotfiles/

# Make shell scripts executable
find . -name "*.sh" -type f -exec chmod +x {} +

./install.sh