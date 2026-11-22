#!/usr/bin/env bash
# Devcontainer install script. VS Code's dotfiles.installCommand runs it inside
# a new devcontainer, after cloning this repo to dotfiles.targetPath (see
# docs/setup/devcontainer.md). It installs this flake's devcontainer package
# into the Nix profile, then applies the dotfiles with chezmoi. isDevcontainer
# (see .chezmoi.yaml.tmpl and .chezmoiignore.tmpl) skips the run_ scripts,
# which provision a host, and mise's global tools, so the container only gets
# the project's tools.
#
# VS Code can open terminals before this finishes. Their zsh reads a
# placeholder ~/.zshenv, init-devcontainer-zshenv.zsh, which says the dotfiles
# are still installing and reports the status this script writes on exit: ok
# or failed.
set -euo pipefail

repo=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
state="$HOME/.local/state/dotfiles"

mkdir -p "$state"
rm -f "$state/devcontainer-status"
exec > >(tee "$state/init-devcontainer.log") 2>&1
trap 'if [ $? -eq 0 ]; then echo ok; else echo failed; fi > "$state/devcontainer-status"' EXIT

# Never replaces a real ~/.zshenv, only stages one for chezmoi to replace
if [ ! -e "$HOME/.zshenv" ]; then
    cp "$repo/init-devcontainer-zshenv.zsh" "$HOME/.zshenv"
fi

if ! command -v nix >/dev/null; then
    echo "init-devcontainer.sh: nix isn't on PATH. Add the ghcr.io/devcontainers/features/nix feature to the devcontainer." >&2
    exit 1
fi

nix --extra-experimental-features 'nix-command flakes' profile add "$repo#devcontainer"

# --promptDefaults answers .chezmoi.yaml.tmpl's prompts with their defaults,
# since nothing can answer them here
CHEZMOI_DEVCONTAINER=1 chezmoi init --apply --promptDefaults --source "$repo"
