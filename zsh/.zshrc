# If you come from bash you might have to change your $PATH.
export PATH="$HOME/.pyenv/shims:$PATH"
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
else
# Mx CPU specific settings
    source "/opt/homebrew/opt/spaceship/spaceship.zsh"
fi

## Warp terminal config
if [[ $TERM_PROGRAM == "WarpTerminal"  ]]; then
  SPACESHIP_PROMPT_ASYNC=FALSE
  ## SPACESHIP_PROMPT_SEPARATE_LINE=FALSE

  spaceship remove char
fi

## #region FNM integration
eval "$(fnm env --use-on-cd --shell zsh)"
autoload -U add-zsh-hook
_fnm_autoload_hook () {
    if [[ -f .node-version || -f .nvmrc ]]; then
    fnm use --silent-if-unchanged
fi

}

add-zsh-hook chpwd _fnm_autoload_hook \
    && _fnm_autoload_hook


FNM_PATH="$HOME/Library/Application Support/fnm"
if [ -d "$FNM_PATH" ]; then
  export PATH="$HOME/Library/Application Support/fnm:$PATH"
  eval "`fnm env`"
fi
## #endregion FNM integration

## Aliases
alias c="open $1 -a \"Visual Studio Code\""
alias grm="git rebase main"
alias grc="git rebase --continue"
alias gtc="git town continue"
alias gpf="git push -f"
alias myip="curl ipinfo.io"

export DISABLE_OPENCOLLECTIVE=1
export ADBLOCK=1
export SPACESHIP_TIME_SHOW=true
# pnpm
export PNPM_HOME="$HOME/Library/pnpm"
export PATH="$PNPM_HOME:$PATH"
# pnpm end
