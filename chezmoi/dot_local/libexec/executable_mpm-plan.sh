#!/bin/sh

# Checks for pending Homebrew updates (via mpm) and posts a notification when updates are pending or
# the check fails. Only checks; installing is manual.
# Run by the mpm-plan systemd user timer.

# The systemd user manager's PATH lacks Homebrew, which mpm searches PATH for
export PATH="/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:/usr/bin:/bin"
cache="$HOME/.cache/mpm"
notify() { notify-send --app-name=mpm "$@"; }
mkdir -p "$cache"
# Checks weekly: the timer fires daily so a failed check is retried, and this skips while the
# last successful check (plan.json is rewritten only on success) is newer
[ -n "$(find "$cache/plan.json" -mtime -7 2>/dev/null)" ] && exit 0
# mpm runs brew with auto-update off, so sync metadata first or it reports stale versions;
# --stop-on-error because sync otherwise exits 0 when a manager fails
mpm --no-color --stop-on-error sync > "$cache/plan.log" 2>&1 &&
  mpm --no-color --table-format json outdated > "$cache/plan.json.tmp" 2>> "$cache/plan.log"
status=$?
if [ "$status" -eq 0 ]; then
  mv "$cache/plan.json.tmp" "$cache/plan.json"
  total=$(jq '[.[].packages | length] | add // 0' "$cache/plan.json")
  if [ "$total" -gt 0 ]; then
    notify "Update(s) available" "mpm found $total update(s). Run 'mpm sync && mpm outdated' to review them."
  fi
else
  rm -f "$cache/plan.json.tmp"
  notify "Couldn't check for updates" "mpm exited $status; see ~/.cache/mpm/plan.log."
fi
