# Other Linux Distros Setup

These get dotfiles alone, with no OS configuration. For Ubuntu 26.04 Desktop,
see [Ubuntu Setup](ubuntu.md).

## Installation

Install the following tools however is appropriate for your distro:

- chezmoi
- Starship
- Sheldon
- Mise
- Delta
- Zsh (make sure to set as default shell)

Then run the below:

```shell
mise use -g python@latest
eval "$(mise env -s zsh)"
chezmoi init --apply natescherer
```
