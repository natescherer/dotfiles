# README

This repository contains my personal dotfiles for synchronization via [chezmoi](https://www.chezmoi.io).

All configurations are set up to work for Windows, macOS, and Ubuntu. Feel free to adapt them to your needs!

Currently managed:

- [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/)
  - <src/dot_zprofile>
- [Bash](https://www.gnu.org/software/bash/)
- [Git](https://git-scm.com/)
- [Nano](https://www.nano-editor.org/)
- [npm](https://www.npmjs.com/)
  - <src/dot_zprofile>
  - <src/dot_config/npm/npmrc>
- [Tabby](https://tabby.sh/)
- [PowerShell](https://github.com/PowerShell/PowerShell)
- [Starship](https://starship.rs)
- [Zsh](https://www.zsh.org/)

## Activating

```shell
chezmoi init natescherer
chezmoi diff
chezmoi apply
```
