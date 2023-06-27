#!/usr/bin/env bash

# Disables natural scroll direction
defaults write NSGlobalDomain com.apple.swipescrolldirection -bool FALSE
# Shows percentage on battery
defaults write ~/Library/Preferences/ByHost/com.apple.controlcenter.plist BatteryShowPercentage -bool true
# Disables recent apps on dock
defaults write com.apple.dock show-recents -bool false
# Remove hot corners
defaults write com.apple.dock wvous-br-corner -int 1
# Disable startup sound
sudo nvram StartupMute=%01

# Kills processes in order to show changes
killall Dock