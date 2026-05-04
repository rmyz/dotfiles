# dotfiles

Configuration and bootstrap scripts to set up a fresh macOS development machine.

## Quick install (new machine)

```bash
curl -fsSL https://raw.githubusercontent.com/rmyz/dotfiles/main/remote-install.sh | bash
```

This bootstraps Homebrew, clones this repo to `~/.dotfiles`, and runs `install.sh`.

## Manual install (already cloned)

```bash
git clone https://github.com/rmyz/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
./install.sh
```

You can also run any folder's installer or symlinks individually:

```bash
cd brew && ./installer.sh   # install Homebrew packages only
cd zsh  && ./symlinks.sh    # set up zsh symlinks only
```

## Layout

| Folder              | Contents                                                                                         |
| ------------------- | ------------------------------------------------------------------------------------------------ |
| `brew/`             | Homebrew taps, formulae, and casks (`Brewfile`); installer runs `brew bundle`.                   |
| `git/`              | Global `~/.gitconfig`.                                                   |
| `mac/`              | macOS `defaults` tweaks: scroll direction, dock, hot corners, Spotlight hotkey, startup sound.   |
| `zsh/`              | `.zshrc`, `.hushlogin`, optional local-only `.zshrc.work.sh`.                                    |
| `starship-prompt/`  | Starship prompt config symlinked to `~/.config/starship.toml`.                                   |
| `agent-skills/`     | AI agent skills symlinked to `~/.agents`.                                                        |
| `raycast/`          | Raycast config backup (manual import via the Raycast app).                                       |

## Conventions

Each folder may contain:

- `installer.sh` — runs once at install time (e.g. `brew bundle`, set macOS defaults).
- `symlinks.sh` — creates symlinks pointing from `$HOME` to files in this repo.

`install.sh` iterates over the folders in a fixed order and runs each script if present. To add a new folder, drop in either or both scripts and add the folder name to the ordered list in `install.sh`.

All `symlinks.sh` scripts use `ln -sfn` so they're safe to re-run; existing links are replaced atomically.

## Local-only work configuration

`zsh/.zshrc.work.sh` is gitignored — create it locally for company- or project-specific aliases and environment variables. It's sourced from `.zshrc` when present, so the absence of this file is harmless on a fresh machine.
