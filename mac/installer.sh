#!/usr/bin/env bash

# Disables natural scroll direction
defaults write NSGlobalDomain com.apple.swipescrolldirection -bool FALSE
# Shows percentage on battery
defaults write com.apple.menuextra.battery ShowPercent YES
# Disables recent apps on dock
defaults write com.apple.dock show-recents -bool false

# Kills processes in order to show changes
killall Dock
killall SystemUIServer