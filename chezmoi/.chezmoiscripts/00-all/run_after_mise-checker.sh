#!/usr/bin/env bash
# Checks whether any tools declared in mise's config (src/dot_config/mise/config.toml,
# applied by chezmoi before any run_after_ script executes) are missing, and runs `mise install`
# to install them if so. Checking first via `mise ls --missing` keeps the common no-op case quiet
# and fast instead of invoking a full `mise install` on every apply.
#
# Why is this in a folder called '00-all'? Directory order is what determines script
# execution order, and 00 is lower than every OS-specific folder (10-linux, 20-linux-and-macos,
# 30-macos, 40-windows, 41-windows, 90-all, 91-macos, 91-windows), so mise-managed tools get
# installed as early as possible for anything later in the apply run that wants them.
#
# Shell, not Python: this script's job is making sure mise-managed tools -- which can include
# Python itself, see config.toml -- are installed, so it can't depend on one of those tools
# already being present just to run. bash is safe to assume this early; a mise-installed
# interpreter wouldn't be.
#
# mise itself is also a documented prerequisite (see README), installed before `chezmoi init
# --apply` is ever run for the first time -- so a missing mise, or a failed `mise install`, is a
# real environment problem rather than a bootstrapping race. This script exits non-zero in those
# cases, which aborts the rest of the apply run.

CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RESET='\033[0m'

mise=$(command -v mise)
if [ -z "$mise" ]; then
    printf "Error: 'mise' is not found on PATH. It is a required prerequisite (see README) and must be installed before running 'chezmoi apply'.\n" >&2
    exit 1
fi

missing=$("$mise" ls --missing 2>/dev/null)
missing_status=$?

if [ "$missing_status" -eq 0 ] && [ -z "$missing" ]; then
    exit 0
fi

if [ "$missing_status" -ne 0 ]; then
    printf "${YELLOW}Warning: 'mise ls --missing' failed; running 'mise install' anyway.${RESET}\n\n" >&2
else
    printf "${CYAN}mise tools missing; running 'mise install'...${RESET}\n\n"
    printf '%s\n' "$missing"
fi

"$mise" install
install_status=$?
if [ "$install_status" -ne 0 ]; then
    printf "Error: 'mise install' exited with code %d.\n" "$install_status" >&2
    exit "$install_status"
fi

exit 0
