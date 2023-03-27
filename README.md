# dotfiles

This repo contains all configuration needed to setup my working environment.

## Installation

Copy and paste this script to get it working:

```bash
#!/bin/bash

# Gets the file from Github
curl -o get-dotfiles.sh "https://raw.githubusercontent.com/rmyz/dotfiles/main/remote-install.sh"

# Give permissions
sudo chmod 777 get-dotfiles.sh

# Execute the script
./get-dotfiles.sh

# Delete it once it has finished
rm get-dotfiles.sh
```
