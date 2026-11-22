# Devcontainer Setup

Devcontainers get the dotfiles without any OS configuration or mise global
tools: the project's `devcontainer.json` provides everything else.

## Requirements

The devcontainer needs:

- The `ghcr.io/devcontainers/features/nix` feature, which
  [init-devcontainer.sh](../../init-devcontainer.sh) uses to install
  chezmoi, Delta, fzf, Sheldon and Starship from this repo's flake
- mise, for the project's own tools
- Zsh, which the `mcr.microsoft.com/devcontainers/base` images include

## Installation

The host's VS Code settings, which chezmoi writes from
[core.json](../../chezmoi/.chezmoitemplates/editors/reusable-settings/core.json),
set:

```jsonc
"dotfiles.installCommand": "init-devcontainer.sh",
"dotfiles.repository": "natescherer/dotfiles"
```

When VS Code creates a devcontainer, the Dev Containers extension clones this
repo to `~/dotfiles` and runs
[init-devcontainer.sh](../../init-devcontainer.sh). The script installs
the flake's `devcontainer` package into the Nix profile, then runs
`chezmoi init --apply` with `CHEZMOI_DEVCONTAINER=1`. That sets chezmoi's
`isDevcontainer`, which skips the `run_` scripts and
`~/.config/mise/conf.d/tools.toml`.
