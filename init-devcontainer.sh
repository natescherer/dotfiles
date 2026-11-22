#!/usr/bin/env bash
# Devcontainer install script. VS Code's dotfiles.installCommand runs it inside
# a new devcontainer, after cloning this repo to dotfiles.targetPath (see
# docs/setup/devcontainer.md). It installs this flake's devcontainer package
# into the Nix profile, then applies the dotfiles with chezmoi. isDevcontainer
# (see .chezmoi.yaml.tmpl and .chezmoiignore.tmpl) skips the run_ scripts,
# which provision a host, and mise's global tools, so the container only gets
# the project's tools.
set -euo pipefail

repo=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

if ! command -v nix >/dev/null; then
    echo "init-devcontainer.sh: nix isn't on PATH. Add the ghcr.io/devcontainers/features/nix feature to the devcontainer." >&2
    exit 1
fi

nix --extra-experimental-features 'nix-command flakes' profile add "$repo#devcontainer"

# --promptDefaults answers .chezmoi.yaml.tmpl's prompts with their defaults,
# since nothing can answer them here
CHEZMOI_DEVCONTAINER=1 chezmoi init --apply --promptDefaults --source "$repo"
