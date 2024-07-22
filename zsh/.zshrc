# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:/usr/local/bin:$PATH

# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

plugins=(
  git
  zsh-autosuggestions
  zsh-completions
  zsh-syntax-highlighting
)

source $ZSH/oh-my-zsh.sh

arch=$(machine)

if [ "$arch" = "x86_64h" ]; then
# Intel CPU specific settings
    source "/usr/local/opt/spaceship/spaceship.zsh"

  #    export NVM_DIR="$HOME/.nvm"
  # [ -s "/usr/local/opt/nvm/nvm.sh" ] && \. "/usr/local/opt/nvm/nvm.sh"  # This loads nvm
  # [ -s "/usr/local/opt/nvm/etc/bash_completion.d/nvm" ] && \. "/usr/local/opt/nvm/etc/bash_completion.d/nvm"  # This loads nvm bash_completion
else
# Mx CPU specific settings
    source "/opt/homebrew/opt/spaceship/spaceship.zsh"

  # export NVM_DIR="$HOME/.nvm"
  # [ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && \. "/opt/homebrew/opt/nvm/nvm.sh"  # This loads nvm
  # [ -s "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm" ] && \. "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm"  # This loads nvm bash_completion
fi

## Warp terminal config
if [[ $TERM_PROGRAM == "WarpTerminal"  ]]; then
  SPACESHIP_PROMPT_ASYNC=FALSE
  ## SPACESHIP_PROMPT_SEPARATE_LINE=FALSE

  spaceship remove char
fi

## #region NVM deeper shell integration
# autoload -U add-zsh-hook

# load-nvmrc() {
#   local nvmrc_path
#   nvmrc_path="$(nvm_find_nvmrc)"

#   if [ -n "$nvmrc_path" ]; then
#     local nvmrc_node_version
#     nvmrc_node_version=$(nvm version "$(cat "${nvmrc_path}")")

#     if [ "$nvmrc_node_version" = "N/A" ]; then
#       nvm install
#     elif [ "$nvmrc_node_version" != "$(nvm version)" ]; then
#       nvm use
#     fi
#   elif [ -n "$(PWD=$OLDPWD nvm_find_nvmrc)" ] && [ "$(nvm version)" != "$(nvm version default)" ]; then
#     echo "Reverting to nvm default version"
#     nvm use default
#   fi
# }

# add-zsh-hook chpwd load-nvmrc
# load-nvmrc
## #endregion NVM deeper shell integration

## #region FNM integration
export PATH="/Users/sromeu/Library/Caches/fnm_multishells/11593_1714389129640/bin":$PATH
export FNM_LOGLEVEL="info"
export FNM_MULTISHELL_PATH="/Users/sromeu/Library/Caches/fnm_multishells/11593_1714389129640"
export FNM_COREPACK_ENABLED="false"
export FNM_RESOLVE_ENGINES="false"
export FNM_VERSION_FILE_STRATEGY="local"
export FNM_NODE_DIST_MIRROR="https://nodejs.org/dist"
export FNM_DIR="/Users/sromeu/Library/Application Support/fnm"
export FNM_ARCH="arm64"
autoload -U add-zsh-hook
_fnm_autoload_hook () {
    if [[ -f .node-version || -f .nvmrc ]]; then
    fnm use --silent-if-unchanged
fi

}

add-zsh-hook chpwd _fnm_autoload_hook \
    && _fnm_autoload_hook

rehash
## #endregion FNM integration

## Aliases
alias grm="git rebase main"
alias grc="git rebase --continue"
alias gpf="git push -f"
alias myip="curl ipinfo.io"

export DISABLE_OPENCOLLECTIVE=1
export ADBLOCK=1

# pnpm
export PNPM_HOME="$HOME/Library/pnpm"
export PATH="$PNPM_HOME:$PATH"
# pnpm end
