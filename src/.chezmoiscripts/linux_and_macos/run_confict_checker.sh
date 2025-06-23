#! /bin/bash

declare -a badpaths=(
    "~/.gitconfig"
    "~/.nanorc"
    "~/.zsh_aliases"
    "~/.zlogin"
    "~/.zprofile"
    "~/.zshrc"
)

for path in "${badpaths[@]}"; do
    if test -f "`eval echo $path`"; then
        printf "\033[0;31mA file was found at '$path' which might conflict with chezmoi config. Please review and delete this file!\033[0m\n"
    fi
done
