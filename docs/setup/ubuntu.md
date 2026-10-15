# Ubuntu Setup

Ubuntu 26.04 Desktop only; for other distros and WSL, see
[Other Linux Distros](linux.md).

## Preflight

1. Install Ubuntu 26.04 Desktop
1. (Optional, VMware VMs only) Install VMware Tools:

   ```shell
   sudo apt-get install -y open-vm-tools-desktop
   ```

1. Install all updates, then reboot if prompted:

   ```shell
   sudo apt-get update && sudo apt-get full-upgrade -y
   ```

## Manual Installation

The Ansible playbook installs everything else and sets zsh as the login shell.

```shell
sudo apt-get install -y build-essential curl file git procps zsh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv bash)"
brew install chezmoi mise
mise use -g python@latest
eval "$(mise env -s bash)"
chezmoi init --apply natescherer
```
