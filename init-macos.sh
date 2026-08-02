#!/usr/bin/env bash

set -euo pipefail

echo -e "\033[1;92m\nSetting up macOS configuration prereqs...\033[0m"

echo -e "\033[1;36m\nInstalling Homebrew...\033[0m"
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" < /dev/tty
echo -e "\033[1;36m\nLoading Homebrew environment...\033[0m"
eval "$(/opt/homebrew/bin/brew shellenv zsh)"
echo -e "\033[1;36m\nInstalling chezmoi...\033[0m"
brew install chezmoi
echo -e "\033[1;36m\nInstalling mise...\033[0m"
brew install mise
echo -e "\033[1;36m\nLoading mise environment...\033[0m"
eval "$(mise env -s zsh)"
echo -e "\033[1;36m\nSetting up Python via mise...\033[0m"
mise use -g python@latest

echo -e "\033[1;92m\nmacOS configuration prereqs set up successfully!\033[0m"
echo -e "\033[1;33m\nRun the following to load your shell environment and finish configuration:\033[0m"
echo -e "\033[1;33m\neval \"\$(/opt/homebrew/bin/brew shellenv zsh)\" && eval \"\$(mise env -s zsh)\" && chezmoi init --apply natescherer\n\033[0m"
