# Linux Servers and WSL Setup

Servers, WSL, and Linux distros other than Ubuntu 26.04 Desktop get the
dotfiles without any OS configuration. For Ubuntu 26.04 Desktop, see
[Ubuntu Setup](ubuntu.md); for NixOS, see [NixOS Setup](nixos.md).

## Requirements

- Zsh, set as the default shell
- Git and curl

## Installation

Install mise, then use it to run chezmoi:

```shell
curl https://mise.run | sh
export PATH="$HOME/.local/bin:$PATH"
mise exec chezmoi -- chezmoi init --apply natescherer
```

On WSL and other machines that aren't workstations, chezmoi writes
[dotfiles-tools.toml](../../chezmoi/dot_config/mise/conf.d/dotfiles-tools.toml)
to `~/.config/mise/conf.d/`, and its mise checker script installs chezmoi,
Delta, fzf, Sheldon, and Starship from it. `~/.zshenv` puts mise and those
tools on `PATH`, so a new Zsh session has everything.

On a Linux desktop that isn't Ubuntu, answer yes when `chezmoi init` asks
whether the machine is a workstation. Workstations get desktop app config and
the global mise tools instead, and need Delta, fzf, Sheldon, and Starship from
the distro's package manager.
