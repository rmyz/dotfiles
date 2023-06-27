#!/usr/bin/env bash

# Removes existing .gitconfig
rm $HOME/.gitconfig

ln -s $PWD/.gitconfig $HOME/.gitconfig