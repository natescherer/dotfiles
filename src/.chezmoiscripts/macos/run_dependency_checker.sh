#! /bin/bash

dependencies=("starship" "fzf" "gls" "sheldon" "mise")

for dep in "${dependencies[@]}"; do
    if ! command -v $dep >/dev/null 2>&1; then
        if [ "$dep" = "glss" ]; then
            echo -e "\033[1;33mWarning: 'gls' is not found. Install it via 'brew install coretools'\033[0m"
        else
            echo -e "\033[1;33mWarning: '$dep' is not found. Install it via 'brew install $dep'\033[0m"
        fi
    fi
done
