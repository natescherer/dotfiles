# Lives in the runtime directory so an update still waiting gets announced
# again at the next login.
marker="$XDG_RUNTIME_DIR/comin-update-notified"

check() {
  local state pending out_path subject

  state=$(comin status --json)
  pending=$(jq -r '.deploy_confirmer.submitted' <<<"$state")
  out_path=$(jq -r --arg uuid "$pending" '
    first(.store.generations[] | select(.uuid == $uuid) | .out_path) // ""
  ' <<<"$state")

  # comin can submit a commit that builds the system already running: it compares
  # against the deployment before the latest one, and has no history on a new host.
  if [ -z "$pending" ] || [ "$out_path" = "$(readlink -f /run/current-system)" ]; then
    rm -f "$marker"
    return
  fi

  if [ "$(cat "$marker" 2>/dev/null)" = "$pending" ]; then
    return
  fi

  subject=$(jq -r --arg uuid "$pending" '
    .store.generations[]
    | select(.uuid == $uuid)
    | .source.git.selected_commit_msg
    | split("\n")[0]
  ' <<<"$state")

  # The marker is written only after a successful send, so a failed send exits
  # the script and the service restart retries it.
  notify-send --app-name="NixOS update" --icon=system-software-update \
    "NixOS update ready" \
    "$subject

Run nixos-update to apply it."

  printf '%s' "$pending" >"$marker"
}

check

# comin submits a generation just after publishing its build-finished event, so
# wait briefly before reading the state.
while read -r _; do
  sleep 5
  check
done < <(comin events)
