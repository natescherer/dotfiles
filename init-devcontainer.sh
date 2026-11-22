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
# placeholder ~/.zshenv, which this script writes before installing anything.
# It says the dotfiles are still installing and reports the status this script
# writes on exit: ok or failed.
set -euo pipefail

repo=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
state="$HOME/.local/state/dotfiles"

mkdir -p "$state"
rm -f "$state/devcontainer-status"
exec > >(tee "$state/init-devcontainer.log") 2>&1
trap 'if [ $? -eq 0 ]; then echo ok; else echo failed; fi > "$state/devcontainer-status"' EXIT

# Never replaces a real ~/.zshenv, only stages one for chezmoi to replace
if [ ! -e "$HOME/.zshenv" ]; then
    # The quoted delimiter writes the zsh code as is, with no bash expansion
    cat > "$HOME/.zshenv" <<'EOF'
# Placeholder from init-devcontainer.sh. chezmoi replaces it with the real
# ~/.zshenv, so only shells that start while the dotfiles are still installing
# read it.
if [[ -o interactive ]]; then
    print 'Dotfiles are still installing; this shell does not have them.'

    # Reports once, at the first prompt after init-devcontainer.sh exits
    _dotfiles_check() {
        case $(cat ~/.local/state/dotfiles/devcontainer-status 2>/dev/null) in
            ok) print 'Dotfiles installed. Run exec zsh to load them.' ;;
            failed) print 'Dotfiles failed to install. See ~/.local/state/dotfiles/init-devcontainer.log' ;;
            *) return ;;
        esac
        add-zsh-hook -d precmd _dotfiles_check
    }

    autoload -Uz add-zsh-hook
    add-zsh-hook precmd _dotfiles_check
fi
EOF
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
