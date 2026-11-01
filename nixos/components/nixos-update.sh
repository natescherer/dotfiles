state=$(comin status --json)
pending=$(jq -r '.deploy_confirmer.submitted' <<<"$state")
out_path=$(jq -r --arg uuid "$pending" '
  first(.store.generations[] | select(.uuid == $uuid) | .out_path) // ""
' <<<"$state")

# comin can submit a commit that builds the system already running: it compares
# against the deployment before the latest one, and has no history on a new host.
if [ -z "$pending" ] || [ "$out_path" = "$(readlink -f /run/current-system)" ]; then
  echo "No update is waiting to be applied. Run 'comin status' for details."
  exit 0
fi

comin confirmation accept

while true; do
  sleep 2

  # The agent can restart at the end of a deployment, so a failed query only
  # means trying again.
  if ! state=$(comin status --json 2>/dev/null); then
    continue
  fi

  status=$(jq -r --arg uuid "$pending" '
    first(.store.deployments[] | select(.generation.uuid == $uuid) | .status) // ""
  ' <<<"$state")

  case "$status" in
    done)
      echo "Update applied."
      if [ "$(jq -r '.need_to_reboot' <<<"$state")" = "true" ]; then
        echo "Reboot to finish applying it."
      fi
      exit 0
      ;;
    failed)
      echo "Update failed: $(jq -r --arg uuid "$pending" '
        first(.store.deployments[] | select(.generation.uuid == $uuid) | .error_msg)
      ' <<<"$state")" >&2
      echo "Run 'journalctl -u comin' for details." >&2
      exit 1
      ;;
  esac
done
