#! /bin/bash

badpaths = (
    "~/.gitconfig"
    "~/.nanorc",
    "~/.zlogin",
    "~/.zprofile",
    "~/.zshrc"
)

for path in "${badpaths[@]}"; do
    if test -f $path; then
        echo "A file was found at '$path' which might conflict with chezmoi config. Please review and delete this file!"
    fi
done