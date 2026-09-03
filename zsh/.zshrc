## Enable automatic directory change
setopt autocd

## Enable shell completions (gh, git-town, k9s, minikube, etc.)
## -u: skip the insecure-dirs prompt (Homebrew makes /opt/homebrew/share group-writable by design)
autoload -U compinit && compinit -u

## FNM integration
eval "$(fnm env --use-on-cd --shell zsh)"

## Aliases
alias vscode="open $1 -a \"Visual Studio Code\""
alias c="open $1 -a Cursor"
alias oc="opencode"
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
export PATH="$HOME/.local/bin:$PATH"
## Zsh plugins
source $(brew --prefix)/share/zsh-autosuggestions/zsh-autosuggestions.zsh
source $(brew --prefix)/share/zsh-fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh
## Work-specific settings (local-only, optional)
[ -f "$HOME/.zshrc.work.sh" ] && source "$HOME/.zshrc.work.sh"

## Starship prompt
eval "$(starship init zsh)"

## AWS Config Bootstrap - auto-clones repo and sources helpers
_aws_config_bootstrap() {
  local repo="${XDG_DATA_HOME:-$HOME/.local/share}/platform-cli-auth"
  if [[ ! -d "$repo" ]]; then
    echo "Setting up AWS config helpers..." >&2
    git clone --quiet git@github.com:elastic/platform-cli-auth.git "$repo" >&2 || return 1
    echo "Done! Run 'aws-config set <role>' to configure your AWS profiles." >&2
  fi
  source "$repo/aws-config/shell-helper.sh" 2>/dev/null
  source "$repo/aws-config/mfa" 2>/dev/null
}
_aws_config_bootstrap
unset -f _aws_config_bootstrap

if command -v wt >/dev/null 2>&1; then eval "$(command wt config shell init zsh)"; fi
