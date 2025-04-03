# README

This repository contains my personal dotfiles for synchronization via [chezmoi](https://www.chezmoi.io).

All configurations are set up to work for macOS 15, Ubuntu 24.04, and Windows 11. Feel free to adapt them to your needs!

Currently managed:

- [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/)
  - Config Files
    - <src/.chezmoitemplates/bash_and_zsh/env.sh.tmpl> via <src/dot_zshenv> and <src/dot_bash_profile.tmpl>
    - <src/.chezmoitemplates/powershell/env.ps1.tmpl> via <src/Documents/PowerShell/env.ps1.tmpl> (Windows) and <src/dot_config/powershell/env.ps1.tmpl> (Linux/macOS)
- [Bash](https://www.gnu.org/software/bash/)
  - Notes
    - Bash configuration is just enough to support bash-only servers, first-class shell experiences are Zsh or Powershell
  - Config Files
    - <src/.chezmoitemplates/bash_and_zsh/aliases.sh.tmpl> via <src/dot_bash_aliases.tmpl>
    - <src/.chezmoitemplates/bash_and_zsh/env.sh.tmpl> via <src/dot_bash_profile.tmpl>
    - <src/dot_bash_profile.tmpl>
    - <srv/dot_bashrc>
- [Git](https://git-scm.com/)
  - Config Files
    - <src/dot_config/git/config.tmpl>
- [Nano](https://www.nano-editor.org/)
  - Config Files
    - <src/.chezmoitemplates/bash_and_zsh/env.sh.tmpl> via <src/dot_zshenv> and <src/dot_bash_profile.tmpl>
    - <src/.chezmoitemplates/powershell/env.ps1.tmpl> via <src/Documents/PowerShell/env.ps1.tmpl> (Windows) and <src/dot_config/powershell/env.ps1.tmpl> (Linux/macOS)
    - <src/dot_config/nano/nanorc>
    - Contents of <src/dot_config/nano/includes>
      - This is a redistribution of <https://github.com/scopatz/nanorc>
- [npm](https://www.npmjs.com/)
  - Config Files
    - <src/.chezmoitemplates/bash_and_zsh/env_vars.sh.tmpl> via <src/dot_zshenv> and <src/dot_bash_profile.tmpl>
    - <src/.chezmoitemplates/powershell/env.ps1.tmpl> via <src/Documents/PowerShell/env.ps1.tmpl> (Windows) and <src/dot_config/powershell/env.ps1.tmpl> (Linux/macOS)
    - <src/dot_config/npm/npmrc>
- [Tabby](https://tabby.sh/)
  - Config Files
    - <src/.chezmoitemplates/tabby/config.yaml.tmpl> via <src/AppData/Roaming/tabby/config.yaml.tmpl> (Windows) and <src/dot_config/tabby/config.yaml.tmpl> (Linux) and <src/Library/Application%20Support/tabby/config.yaml.tmpl> (macOS)
- [PowerShell](https://github.com/PowerShell/PowerShell)
  - <src/.chezmoitemplates/powershell/aliases.ps1.tmpl> via <src/Documents/PowerShell/aliases.ps1.tmpl> (Windows) and <src/dot_config/powershell/aliases.ps1.tmpl> (Linux/macOS)
  - <src/.chezmoitemplates/powershell/env.ps1.tmpl> via <src/Documents/PowerShell/env.ps1.tmpl> (Windows) and <src/dot_config/powershell/env.ps1.tmpl> (Linux/macOS)
  - <src/.chezmoitemplates/powershell/profile.ps1.tmpl> via <src/Documents/PowerShell/profile.ps1.tmpl> (Windows) and <src/dot_config/powershell/profile.ps1.tmpl> (Linux/macOS)
- [Starship](https://starship.rs)
  - <src/dot_config/starship.toml.tmpl>
- [Zsh](https://www.zsh.org/)
  - <src/.chezmoitemplates/bash_and_zsh/aliases.sh.tmpl> via <src/dot_config/zsh/dot_zsh_aliases.tmpl>
  - <src/dot_config/zsh/dot_zshrc.tmpl>
  - <src/dot_zshenv.tmpl>

## Activating

```shell
chezmoi init natescherer
chezmoi diff
chezmoi apply
```
