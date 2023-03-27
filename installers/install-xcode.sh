#!/usr/bin/env bash

if test ! $(which xcode-select); then
    echo "Installing xcode-select..."
    xcode-select install
fi
