# Devcontainer Setup

Devcontainers get the dotfiles without any OS configuration or mise global
tools: the project's `devcontainer.json` provides everything else.

## Requirements

The devcontainer needs:

- A Debian-based image, such as `mcr.microsoft.com/devcontainers/base:debian`,
  which includes Zsh
- mise, from the `ghcr.io/devcontainers-extra/features/mise` feature, which
  installs both the project's tools and the tools the dotfiles need

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
[init-devcontainer.sh](../../init-devcontainer.sh). The script copies
[dotfiles-tools.toml](../../chezmoi/dot_config/mise/conf.d/dotfiles-tools.toml)
to `~/.config/mise/conf.d/` and runs `mise install`, which installs chezmoi,
Delta, fzf, Sheldon and Starship. It then runs `chezmoi init --apply` with
`CHEZMOI_DEVCONTAINER=1`. That sets chezmoi's `isDevcontainer`, which skips
the `run_` scripts. A devcontainer isn't a workstation, so it also skips
`~/.config/mise/conf.d/tools.toml`, and `~/.zshenv` adds mise's shims
directory to `PATH`, since `.zshrc` runs Sheldon before it activates mise.

## Knowing When Setup Has Finished

VS Code connects, and can open terminals, before the dotfiles finish
installing. Before installing anything,
[init-devcontainer.sh](../../init-devcontainer.sh) writes a placeholder
`~/.zshenv`, unless one already exists. A terminal that starts during setup
reads it and prints:

```text
Dotfiles are still installing; this shell does not have them.
```

At its first prompt after setup ends, it prints one of:

```text
Dotfiles installed. Run exec zsh to load them.
Dotfiles failed to install. See ~/.local/state/dotfiles/init-devcontainer.log
```

chezmoi replaces the placeholder with the real `~/.zshenv`, so terminals opened
after setup print nothing. The script writes `ok` or `failed` to
`~/.local/state/dotfiles/devcontainer-status` when it exits, and its output to
`~/.local/state/dotfiles/init-devcontainer.log`.
