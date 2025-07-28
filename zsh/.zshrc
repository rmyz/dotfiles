## Machine specific settings
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

  spaceship remove char
fi

## FNM integration
eval "$(fnm env --use-on-cd --shell zsh)"
autoload -U add-zsh-hook
_fnm_autoload_hook () {
    if [[ -f .node-version || -f .nvmrc ]]; then
    fnm use --silent-if-unchanged
fi
}
add-zsh-hook chpwd _fnm_autoload_hook \
    && _fnm_autoload_hook

## Aliases
alias c="open $1 -a \"Visual Studio Code\""
alias grm="git rebase main"
alias grc="git rebase --continue"
alias gtc="git town continue"
alias gpf="git push -f"
alias gs="git sync"
alias myip="curl ipinfo.io"

## Generic settings
export DISABLE_OPENCOLLECTIVE=1
export ADBLOCK=1
export SPACESHIP_TIME_SHOW=true
export HOMEBREW_GITHUB_API_TOKEN=$(gh auth token)

## PATHs
export GOPATH=$HOME/go
export GOBIN=$HOME/bin/go
export PATH=$PATH:$GOPATH/bin:$GOBIN:$GOBIN/elastic-package
export PATH="/opt/homebrew/opt/openjdk/bin:$PATH"
export PATH="$HOME/.pyenv/shims:$PATH"
export PATH="/Users/sromeu/.codeium/windsurf/bin:$PATH"

source ./zshrc.work

source $(brew --prefix)/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
