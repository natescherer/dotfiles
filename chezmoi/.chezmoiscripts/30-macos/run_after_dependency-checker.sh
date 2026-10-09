#!/usr/bin/env bash

dependencies=("starship" "fzf" "gls" "sheldon" "mise" "delta" "jq" "terminal-notifier" "mpm")

for dep in "${dependencies[@]}"; do
    if ! command -v $dep >/dev/null 2>&1; then
        if [ "$dep" = "gls" ]; then
            echo -e "\033[1;33mWarning: 'gls' is not found. Install it via 'brew install coreutils'\033[0m"
        elif [ "$dep" = "delta" ]; then
            echo -e "\033[1;33mWarning: 'delta' is not found. Install it via 'brew install git-delta'\033[0m"
        elif [ "$dep" = "mpm" ]; then
            echo -e "\033[1;33mWarning: 'mpm' is not found. Install it via 'brew install meta-package-manager'\033[0m"
        else
            echo -e "\033[1;33mWarning: '$dep' is not found. Install it via 'brew install $dep'\033[0m"
        fi
    fi
done
