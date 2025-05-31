# README
<!-- markdownlint-disable MD033 -->

This repository contains my personal dotfiles for synchronization via [chezmoi](https://www.chezmoi.io).

Where possible, each configuration is set up to work for Linux 🐧, macOS 15 🍎, and Windows 11 🪟. (OS compatibility for each product is indicated with emoji.)

Feel free to use anything here according to your needs!

Currently managed:

- [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/) 🐧 🍎 🪟
  - Config Files
    - [src/.chezmoitemplates/bash_and_zsh/env.sh.tmpl](src/.chezmoitemplates/bash_and_zsh/env.sh.tmpl) via [src/dot_zshenv](src/dot_zshenv) and [src/dot_bash_profile.tmpl](src/dot_bash_profile.tmpl)
    - [src/.chezmoitemplates/powershell/env.ps1.tmpl](src/.chezmoitemplates/powershell/env.ps1.tmpl) via [src/Documents/PowerShell/env.ps1.tmpl](src/Documents/PowerShell/env.ps1.tmpl) (🪟) and [src/dot_config/powershell/env.ps1.tmpl](src/dot_config/powershell/env.ps1.tmpl) (🐧 🍎)
- [Bash](https://www.gnu.org/software/bash/) 🐧 🍎
  - Notes
    - Bash configuration is just enough to support bash-only servers, first-class shell experiences are Zsh or Powershell
  - Config Files
    - [src/.chezmoitemplates/bash_and_zsh/aliases.sh.tmpl](src/.chezmoitemplates/bash_and_zsh/aliases.sh.tmpl) via [src/dot_bash_aliases.tmpl](src/dot_bash_aliases.tmpl)
    - [src/.chezmoitemplates/bash_and_zsh/env.sh.tmpl](src/.chezmoitemplates/bash_and_zsh/env.sh.tmpl) via [src/dot_bash_profile.tmpl](src/dot_bash_profile.tmpl)
    - [src/dot_bash_profile.tmpl](src/dot_bash_profile.tmpl)
    - [src/dot_bashrc](src/dot_bashrc)
- [Clocker](https://abhishekbanthia.com/clocker/) 🍎
  - Notes
    - Configuration is managed by script [src/.chezmoiscripts/macos/run_after_defaults-importer.sh.tmpl](src/.chezmoiscripts/macos/run_after_defaults-importer.sh.tmpl)
    - files under dot_config/defaults should not be edited directly, they are exports from the macOS defaults system managed by the scripts mentioned above
  - Config Files
    - [srv/.chezmoidata/macos_defaults.yaml](srv/.chezmoidata/macos_defaults.yaml)
    - [src/dot_config/defaults/com.abhishek.Clocker](src/dot_config/defaults/com.abhishek.Clocker)
- [Git](https://git-scm.com/) 🐧 🍎 🪟
  - Config Files
    - [src/dot_config/git/config.tmpl](src/dot_config/git/config.tmpl)
- [Nano](https://www.nano-editor.org/) 🐧 🍎 🪟
  - Config Files
    - [src/.chezmoitemplates/bash_and_zsh/env.sh.tmpl](src/.chezmoitemplates/bash_and_zsh/env.sh.tmpl) via [src/dot_zshenv](src/dot_zshenv) and [src/dot_bash_profile.tmpl](src/dot_bash_profile.tmpl)
    - [src/.chezmoitemplates/powershell/env.ps1.tmpl](src/.chezmoitemplates/powershell/env.ps1.tmpl) via [src/Documents/PowerShell/env.ps1.tmpl](src/Documents/PowerShell/env.ps1.tmpl) (🪟) and [src/dot_config/powershell/env.ps1.tmpl](src/dot_config/powershell/env.ps1.tmpl) (🐧 🍎)
    - [src/dot_config/nano/nanorc](src/dot_config/nano/nanorc)
    - Contents of [src/dot_config/nano/includes](src/dot_config/nano/includes)
      - This is a redistribution of [https://github.com/scopatz/nanorc](https://github.com/scopatz/nanorc)
- [npm](https://www.npmjs.com/) 🐧 🍎 🪟
  - Config Files
    - [src/.chezmoitemplates/bash_and_zsh/env_vars.sh.tmpl](src/.chezmoitemplates/bash_and_zsh/env_vars.sh.tmpl) via [src/dot_zshenv](src/dot_zshenv) and [src/dot_bash_profile.tmpl](src/dot_bash_profile.tmpl)
    - [src/.chezmoitemplates/powershell/env.ps1.tmpl](src/.chezmoitemplates/powershell/env.ps1.tmpl) via [src/Documents/PowerShell/env.ps1.tmpl](src/Documents/PowerShell/env.ps1.tmpl) (🪟) and [src/dot_config/powershell/env.ps1.tmpl](src/dot_config/powershell/env.ps1.tmpl) (🐧 🍎)
    - [src/dot_config/npm/npmrc](src/dot_config/npm/npmrc)
- [Tabby](https://tabby.sh/) 🐧 🍎 🪟
  - Config Files
    - [src/.chezmoitemplates/tabby/config.yaml.tmpl](src/.chezmoitemplates/tabby/config.yaml.tmpl) via [src/AppData/Roaming/tabby/config.yaml.tmpl](src/AppData/Roaming/tabby/config.yaml.tmpl) (🪟) and [src/dot_config/tabby/config.yaml.tmpl](src/dot_config/tabby/config.yaml.tmpl) (🐧) and [src/Library/Application%20Support/tabby/config.yaml.tmpl](src/Library/Application%20Support/tabby/config.yaml.tmpl) (🍎)
- [PowerShell](https://github.com/PowerShell/PowerShell) 🐧 🍎 🪟
  - Config Files
    - [src/.chezmoitemplates/powershell/aliases.ps1.tmpl](src/.chezmoitemplates/powershell/env.ps1.tmpl) via [src/Documents/PowerShell/aliases.ps1.tmpl](src/Documents/PowerShell/aliases.ps1.tmpl) (🪟) and [src/dot_config/powershell/aliases.ps1.tmpl](src/dot_config/powershell/aliases.ps1.tmpl) (🐧 🍎)
    - [src/.chezmoitemplates/powershell/env.ps1.tmpl](src/.chezmoitemplates/powershell/env.ps1.tmpl) via [src/Documents/PowerShell/env.ps1.tmpl](src/Documents/PowerShell/env.ps1.tmpl) (🪟) and [src/dot_config/powershell/env.ps1.tmpl](src/dot_config/powershell/env.ps1.tmpl) (🐧 🍎)
    - [src/.chezmoitemplates/powershell/profile.ps1.tmpl](src/.chezmoitemplates/powershell/profile.ps1.tmpl) via [src/Documents/PowerShell/profile.ps1.tmpl](src/Documents/PowerShell/profile.ps1.tmpl) (🪟) and [src/dot_config/powershell/profile.ps1.tmpl](src/dot_config/powershell/profile.ps1.tmpl) (🐧 🍎)
- [Sheldon](https://github.com/rossmacarthur/sheldon) 🐧 🍎
  - Config Files
    - [src/dot_config/sheldon/plugins.toml]
- [Starship](https://starship.rs) 🐧 🍎 🪟
  - Config Files
    - [src/dot_config/starship.toml.tmpl](src/dot_config/starship.toml.tmpl)
- [Stats](https://github.com/exelban/stats) 🍎
  - Notes
    - Configuration is managed by script [src/.chezmoiscripts/macos/run_after_defaults-importer.sh.tmpl](src/.chezmoiscripts/macos/run_after_defaults-importer.sh.tmpl)
    - files under dot_config/defaults should not be edited directly, they are exports from the macOS defaults system managed by the scripts mentioned above
  - Config Files
    - [srv/.chezmoidata/macos_defaults.yaml](srv/.chezmoidata/macos_defaults.yaml)
  - Config Files
    - [src/dot_config/defaults/eu.exelban.Stats](src/dot_config/defaults/eu.exelban.Stats)
- [Zsh](https://www.zsh.org/) 🐧 🍎
  - Config Files
    - [src/.chezmoitemplates/bash_and_zsh/aliases.sh.tmpl](src/.chezmoitemplates/bash_and_zsh/aliases.sh.tmpl) via [src/dot_config/zsh/dot_zsh_aliases.tmpl](src/dot_config/zsh/dot_zsh_aliases.tmpl)
    - [src/dot_config/zsh/dot_zshrc.tmpl](src/dot_config/zsh/dot_zshrc.tmpl)
    - [src/dot_zshenv.tmpl](src/dot_zshenv.tmpl)

## Activating

```shell
chezmoi init natescherer
chezmoi diff
chezmoi apply
```
