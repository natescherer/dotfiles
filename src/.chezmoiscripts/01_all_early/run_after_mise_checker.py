#!/usr/bin/env python3
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
# This script never exits non-zero: a failing run_after_ script aborts the rest of the apply run,
# and on a fresh machine mise itself isn't installed until winget-configure/the OS dependency
# scripts run later in this same apply. It warns and defers to the next apply instead.

import json
import os
import platform
import shutil
import subprocess
import sys

IS_WINDOWS = platform.system() == "Windows"

if IS_WINDOWS:
    # Installs from earlier chezmoi runs (or a winget install done in another window) write PATH
    # changes straight to the registry, but this process inherits whatever PATH chezmoi's own
    # process was started with. Rebuilding PATH from the registry (Machine + User, same precedence
    # Windows itself uses) picks up a mise that the launching shell hasn't seen yet.
    import winreg

    def _registry_path(hive, subkey):
        try:
            with winreg.OpenKey(hive, subkey) as key:
                value, _ = winreg.QueryValueEx(key, "Path")
                return value
        except FileNotFoundError:
            return ""

    _machine_path = _registry_path(winreg.HKEY_LOCAL_MACHINE, r"SYSTEM\CurrentControlSet\Control\Session Manager\Environment")
    _user_path = _registry_path(winreg.HKEY_CURRENT_USER, "Environment")
    os.environ["PATH"] = _machine_path + os.pathsep + _user_path

CYAN_TERM_COLOR = "\033[0;36m"
YELLOW_TERM_COLOR = "\033[1;33m"
RESET_TERM_STYLE = "\033[0m"


def missing_tools(mise):
    result = subprocess.run(
        [mise, "ls", "--missing", "--json"],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        return None
    try:
        return json.loads(result.stdout)
    except json.JSONDecodeError:
        return None


def main():
    mise = shutil.which("mise")
    if mise is None:
        print(
            f"{YELLOW_TERM_COLOR}Warning: 'mise' is not found; skipping mise tool install. "
            f"It should be installed later in this apply run - re-run 'chezmoi apply' "
            f"afterward to install mise-managed tools.{RESET_TERM_STYLE}\n",
            file=sys.stderr,
        )
        return

    missing = missing_tools(mise)
    if missing == {}:
        return

    if missing is None:
        # The check itself failed (e.g. unparsable config); let `mise install` surface the
        # real error message.
        print(
            f"{YELLOW_TERM_COLOR}Warning: 'mise ls --missing' failed; "
            f"running 'mise install' anyway.{RESET_TERM_STYLE}\n",
            file=sys.stderr,
        )
    else:
        names = ", ".join(sorted(missing))
        print(f"{CYAN_TERM_COLOR}mise tools missing ({names}); running 'mise install'...{RESET_TERM_STYLE}\n")

    result = subprocess.run([mise, "install"])
    if result.returncode != 0:
        print(
            f"{YELLOW_TERM_COLOR}Warning: 'mise install' exited with code {result.returncode}. "
            f"It will be retried on the next 'chezmoi apply'.{RESET_TERM_STYLE}\n",
            file=sys.stderr,
        )


if __name__ == "__main__":
    main()
