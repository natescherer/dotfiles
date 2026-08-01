#!/usr/bin/env bash
# Checks whether any tools declared in mise's config (src/dot_config/mise/config.toml,
# applied by chezmoi before any run_after_ script executes) are missing, and runs `mise install`
# to install them if so. Checking first via `mise ls --missing` keeps the common no-op case quiet
# and fast instead of invoking a full `mise install` on every apply.
#
# Why is this in a folder called '01_all_early'? Directory order is what determines script
# execution order, and 01 is lower than every OS-specific folder (10-linux, 20-linux_and_macos,
# 30-macos, 40-windows, 41-windows_late, 99-all_late), so mise-managed tools get installed as
# early as possible for anything later in the apply run that wants them.
#
# Shell, not Python: this script's job is making sure mise-managed tools -- which can include
# Python itself, see config.toml -- are installed, so it can't depend on one of those tools
# already being present just to run. bash is safe to assume this early; a mise-installed
# interpreter wouldn't be.
#
# This script never exits non-zero: a failing run_after_ script aborts the rest of the apply run,
# and on a fresh machine mise itself isn't installed until the OS dependency scripts run later in
# this same apply. It warns and defers to the next apply instead.

CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RESET='\033[0m'

mise=$(command -v mise)
if [ -z "$mise" ]; then
    printf "${YELLOW}Warning: 'mise' is not found; skipping mise tool install. It should be installed later in this apply run - re-run 'chezmoi apply' afterward to install mise-managed tools.${RESET}\n\n" >&2
    exit 0
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
    printf "${YELLOW}Warning: 'mise install' exited with code %d. It will be retried on the next 'chezmoi apply'.${RESET}\n\n" "$install_status" >&2
fi

exit 0
