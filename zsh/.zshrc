## Enable automatic directory change
setopt autocd

## Enable shell completions (gh, git-town, k9s, minikube, etc.)
autoload -U compinit && compinit

## FNM integration
eval "$(fnm env --use-on-cd --shell zsh)"

## Aliases
alias vscode="open $1 -a \"Visual Studio Code\""
alias c="open $1 -a Cursor"
alias grm="git rebase main"
alias grc="git rebase --continue"
alias gtc="git town continue"
alias gpf="git push -f"
alias gs="git sync"
alias myip="curl ipinfo.io"

## Generic settings
export DISABLE_OPENCOLLECTIVE=1
export ADBLOCK=1
export HOMEBREW_GITHUB_API_TOKEN="$(command -v gh >/dev/null 2>&1 && gh auth token 2>/dev/null)"
export USE_GKE_GCLOUD_AUTH_PLUGIN=True

## PATHs
export GOPATH=$HOME/go
export GOBIN=$HOME/bin/go
export PATH=$PATH:$GOPATH/bin:$GOBIN:$GOBIN/elastic-package
export PATH="/opt/homebrew/opt/openjdk/bin:$PATH"
export PATH="$HOME/.pyenv/shims:$PATH"
export GPG_TTY=$(tty)
export PATH="$PATH:/Applications/Docker.app/Contents/Resources/bin/"
export PATH="/opt/homebrew/share/google-cloud-sdk/bin:$PATH"

## Zsh plugins
source $(brew --prefix)/share/zsh-fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh

## Work-specific settings (local-only, optional)
[ -f "$HOME/.zshrc.work.sh" ] && source "$HOME/.zshrc.work.sh"

## Starship prompt
eval "$(starship init zsh)"
