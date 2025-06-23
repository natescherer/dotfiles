#! /bin/bash

echo "running dep checker"

dependencies=("starship" "gls" "sheldon" "mise")

for dep in "${dependencies[@]}"; do
    echo "$dep bp1"
    if ! command -v $dep >/dev/null 2>&1; then
        echo "bp2"
        if [ "$dep" = "glss" ]; then
            echo "bp3"
            echo "Warning: 'gls' is not found. Install it via 'brew install coretools'"
        else
            echo "bp4"
            echo "Warning: '$dep' is not found. Install it via 'brew install $dep'"
        fi
    fi
done
