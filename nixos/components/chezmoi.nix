{
  pkgs,
  lib,
  specialArgs,
  ...
}: let
  # `or null` (rather than a bare attribute access) means removing the
  # dotfilesRepo line from the flake entirely - not just setting it to null -
  # still evaluates cleanly instead of hitting a missing attribute error.
  dotfilesRepo = specialArgs.dotfilesRepo or null;
  home = "/home/${specialArgs.userName}";
  chezmoiSourceDir = "${home}/.local/share/chezmoi";

  # `chezmoi init` can run arbitrary prompts from a .chezmoi.toml.tmpl in the
  # target repo, which would hang forever with no TTY attached to a systemd
  # service. So init is never run automatically; this is nagged at interactive
  # login (see programs.zsh.interactiveShellInit below) until the user has run
  # it themselves. Evaluated fresh on every login rather than baked into a
  # static /etc/motd, so it disappears the moment init actually finishes
  # instead of lagging until the next switch.
  nagMessage = pkgs.writeText "chezmoi-nag" ''
    chezmoi has not been initialized for ${specialArgs.userName} yet. Run this once, interactively, to set it up:

      chezmoi init --apply ${dotfilesRepo}
  '';
in {
  # Wrapping the whole module in config = mkIf here (rather than gating each
  # option individually) means this component is a true no-op - no package,
  # no service, no shell hook - whenever dotfilesRepo isn't set.
  config = lib.mkIf (dotfilesRepo != null) {
    environment.systemPackages = [pkgs.chezmoi];

    programs.zsh.interactiveShellInit = ''
      if [ "$(id -un)" = ${lib.escapeShellArg specialArgs.userName} ] && [ ! -d ${lib.escapeShellArg chezmoiSourceDir} ]; then
        cat ${nagMessage}
      fi
    '';

    # Runs on every activation (boot, and every `nixos-rebuild switch`,
    # including the ones nixos-fancy-updater runs on its own schedule).
    system.activationScripts.chezmoiUpdate = ''
      if [ -d ${lib.escapeShellArg chezmoiSourceDir} ]; then
        ${pkgs.systemd}/bin/systemctl start --no-block chezmoi-update.service
      fi
    '';

    systemd.services.chezmoi-update = {
      description = "Pull and apply chezmoi-managed dotfiles for ${specialArgs.userName}";
      after = ["network-online.target"];
      wants = ["network-online.target"];
      serviceConfig = {
        Type = "oneshot";
        User = specialArgs.userName;
      };
      # bash is included explicitly (not just pulled in transitively) since
      # chezmoi.$OS run scripts commonly shebang `#!/usr/bin/env bash` -
      # NixOS has no /bin/bash for a hardcoded `#!/bin/bash` to find, so
      # scripts need the env-based form, and env needs bash on PATH to
      # actually resolve it. mise is the interpreter for the dotfiles' Python
      # scripts.
      path = [pkgs.chezmoi pkgs.gitMinimal pkgs.bash pkgs.mise];
      script = ''
        set -euo pipefail
        # Defensive: the activation script above only starts this once the
        # source directory exists, but this stays safe if it's ever started
        # manually (e.g. testing) before that.
        if [ ! -d ${lib.escapeShellArg chezmoiSourceDir} ]; then
          echo "chezmoi not yet initialized for ${specialArgs.userName}; skipping."
          exit 0
        fi
        # --force: this runs unattended, so a local edit to a chezmoi-managed
        # file since the last run must lose to the source repo rather than
        # hang the service waiting on a prompt that will never be answered.
        chezmoi update --force
      '';
    };
  };
}
