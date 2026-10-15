# macOS Setup

## Preflight

1. Install macOS, logging into Apple Account (unless a VM)
1. Set hostname

## Automatic Installation

macOS prerequisites can be automatically installed by running the
below:

```shell
curl -fS https://raw.githubusercontent.com/natescherer/dotfiles/main/init-macos.sh | bash
```

## Manual Installation

```shell
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
eval "$(/opt/homebrew/bin/brew shellenv zsh)"
brew install chezmoi
brew install mise
mise use -g python@latest
eval "$(mise env -s zsh)"
chezmoi init --apply natescherer
```
