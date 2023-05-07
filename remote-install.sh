#!/usr/bin/env bash

## install brew
NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

## install git
brew install git

## clone repo
git clone https://github.com/rmyz/dotfiles.git .dotfiles

cd .dotfiles/

# Give permissions to all files
for file in $(find . -type f)
do
  sudo chmod 777 "$file"
done

./install.sh