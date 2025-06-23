#! /bin/bash

echo "running dep checker"

dependencies=("starship" "gls" "sheldon" "mise")

for dep in $dependencies; do
    if ! command -v $dep >/dev/null 2>&1; then
        if [ "$dep" = "glss" ]; then
            echo "Warning: 'gls' is not found. Install it via 'brew install coretools'"
        else
            echo "Warning: '$dep' is not found. Install it via 'brew install $dep'"
        fi
    fi
done
