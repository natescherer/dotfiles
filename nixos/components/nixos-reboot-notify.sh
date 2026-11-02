# Lives in the runtime directory so a reboot still pending gets announced again
# at the next login.
marker="$XDG_RUNTIME_DIR/nixos-reboot-notified"

if [ "$(readlink -f /nix/var/nix/profiles/system)" = "$(readlink -f /run/current-system)" ]; then
  rm -f "$marker"
  exit 0
fi

if [ -e "$marker" ]; then
  exit 0
fi

# Without an expiry, the notification stays until dismissed. The marker is
# written only after a successful send, so a failed send exits the script and
# the service restart retries it.
notify-send --app-name="NixOS update" --icon=system-reboot \
  --urgency=critical --expire-time=0 \
  "Reboot needed" \
  "A NixOS update will apply at the next reboot."

touch "$marker"
