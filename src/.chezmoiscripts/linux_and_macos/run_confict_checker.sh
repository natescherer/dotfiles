#! /bin/bash

declare -a badpaths=(
    "~/.gitconfig"
    "~/.nanorc"
    "~/.zlogin"
    "~/.zprofile"
    "~/.zshrc"
)

for path in "${badpaths[@]}"; do
    if test -f "`eval echo $path`"; then 
        echo -e "\e[31mA file was found at '$path' which might conflict with chezmoi config. Please review and delete this file!\e[0m"
    fi
done