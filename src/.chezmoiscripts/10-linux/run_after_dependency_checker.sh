#!/usr/bin/env bash

dependencies=("starship" "fzf" "sheldon" "mise")

for dep in "${dependencies[@]}"; do
    if ! command -v $dep >/dev/null 2>&1; then
        echo -e "\033[1;33mWarning: '$dep' is not found. Install it via whatever method is appropriate for your distro.\033[0m"
    fi
done
