#!/usr/bin/env bash

# Removes existing .zshrc
rm $HOME/.zshrc

ln -s $PWD/.zshrc $HOME/.zshrc