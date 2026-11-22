#!/usr/bin/env bash

dependencies=("starship" "fzf" "sheldon" "mise" "delta")

for dep in "${dependencies[@]}"; do
    if ! command -v $dep >/dev/null 2>&1; then
        formula=$dep
        if [ "$dep" = "delta" ]; then
            formula="git-delta"
        fi
        echo -e "\033[1;33mWarning: '$dep' is not found. Install it via 'brew install $formula' or your distro's package manager.\033[0m"
    fi
done
