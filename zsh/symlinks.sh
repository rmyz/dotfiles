#!/usr/bin/env bash

# Removes existing .zshrc
rm $HOME/.zshrc

ln -s $PWD/.zshrc $HOME/.zshrc
ln -s $PWD/.zshrc.work $HOME/.zshrc.work
