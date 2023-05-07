#!/usr/bin/env bash

if test ! $(which omz); then
    echo "Installing oh my zsh..."
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi