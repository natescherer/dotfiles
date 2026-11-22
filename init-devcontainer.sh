#!/usr/bin/env bash
# Devcontainer install script. VS Code's dotfiles.installCommand runs it inside
# a new devcontainer, after cloning this repo to dotfiles.targetPath (see
# docs/setup/devcontainer.md). It installs chezmoi and the tools the dotfiles
# need with mise, then applies the dotfiles with chezmoi. isDevcontainer
# (see .chezmoi.yaml.tmpl and .chezmoiignore.tmpl) skips the run_ scripts,
# which provision a host, and the host's global mise tools, so the container
# gets only these tools and the project's.
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

if ! command -v mise >/dev/null; then
    echo "init-devcontainer.sh: mise isn't on PATH. Add the ghcr.io/devcontainers-extra/features/mise feature to the devcontainer." >&2
    exit 1
fi

# Stages the tool list that chezmoi manages later, since mise has to install
# chezmoi before chezmoi can apply anything
mkdir -p "$HOME/.config/mise/conf.d"
cp "$repo/chezmoi/dot_config/mise/conf.d/devcontainer.toml" "$HOME/.config/mise/conf.d/"

# Runs mise from $HOME, so it reads only the global config, not a project's
cd "$HOME"
mise install

# --promptDefaults answers .chezmoi.yaml.tmpl's prompts with their defaults,
# since nothing can answer them here
CHEZMOI_DEVCONTAINER=1 mise exec -- chezmoi init --apply --promptDefaults --source "$repo"
