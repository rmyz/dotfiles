#!/usr/bin/env bash

# Install xcode-select
if test ! $(which xcode-select); then
    echo "Installing xcode-select..."
    xcode-select install
fi

# Execute all installer and symlinks scripts
for folder in */
do
  # Change to folder directory
  cd "$folder"

  # Check if installer.sh exists
  if [ -e "installer.sh" ]
  then
    # Check if installer.sh can be executed
    if [ -x "installer.sh" ]
    then
      # Run installer.sh
      echo "Executing $folder's installer..."
      ./installer.sh
    else
      # If it is not executable, show error message
      echo "Can't execute $folder's installer.sh"
    fi
  fi

  # Check if symlinks.sh exists
  if [ -e "symlinks.sh" ]
  then
    # Check if symlinks.sh can be executed
    if [ -x "symlinks.sh" ]
    then
      # Run symlinks.sh
      echo "Executing $folder's symlinks..."
      ./symlinks.sh
    else
      # If it is not executable, show error message
      echo "Can't execute $folder's symlinks.sh"
    fi
  fi

  # Go back to root
  cd ..
done

echo "rmyz dotfiles loaded successfully"