{
  config,
  inputs,
  lib,
  pkgs,
  specialArgs,
  ...
}: let
  # `or null` matches the chezmoi component: removing dotfilesRepo from the
  # flake turns this component into a no-op.
  dotfilesRepo = specialArgs.dotfilesRepo or null;
  cominPackage = config.services.comin.package;

  notifier = pkgs.writeShellApplication {
    name = "comin-update-notify";
    runtimeInputs = [cominPackage pkgs.coreutils pkgs.jq pkgs.libnotify];
    text = builtins.readFile ./comin-update-notify.sh;
  };

  updater = pkgs.writeShellApplication {
    name = "nixos-update";
    runtimeInputs = [cominPackage pkgs.coreutils pkgs.jq];
    text = builtins.readFile ./nixos-update.sh;
  };
in {
  imports = [inputs.comin.nixosModules.comin];

  config = lib.mkIf (dotfilesRepo != null) {
    services.comin = {
      enable = true;
      remotes = [
        {
          name = "origin";
          url = "https://github.com/${dotfilesRepo}.git";
          branches.testing.name = "";
          # comin's poller waits a full period after each start before its first
          # fetch, so a host rebooted daily would never check. The comin-fetch
          # timer below triggers fetches instead.
          poller.period = 0;
        }
      ];
      # comin checks whether a commit changes this host only after building it,
      # so a manual build confirmer would flag every commit in the repo. Builds
      # run unattended and only the switch waits for nixos-update.
      deployConfirmer.mode = "manual";
      # The default of 0 retries a broken build forever, sending a failure
      # notification on each attempt.
      buildAttemptsLimit = 3;
      desktop = {
        enable = true;
        title = "NixOS update";
      };
    };

    # comin desktop exits when the agent restarts, which comin does after a
    # deployment changes its own unit.
    systemd.user.services.comin-desktop.serviceConfig = {
      Restart = "on-failure";
      RestartSec = 10;
    };

    environment.systemPackages = [updater];

    systemd.services.comin-fetch = {
      description = "Fetch the NixOS configuration repository with comin";
      wants = ["network-online.target"];
      after = ["network-online.target" "comin.service"];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${lib.getExe cominPackage} fetch";
      };
    };
    # comin holds a waiting update in memory, so every boot fetches to restore
    # it. OnCalendar also fires on resume if the machine slept through midnight.
    systemd.timers.comin-fetch = {
      description = "Fetch the NixOS configuration repository daily and at boot";
      wantedBy = ["timers.target"];
      timerConfig = {
        OnBootSec = "1min";
        OnCalendar = "daily";
      };
    };

    # comin publishes no event when a generation starts waiting for
    # confirmation, so comin desktop can't announce it. This service checks at
    # login and after each comin event instead. Restarting retries a failed
    # notification and reconnects to the event stream when the agent restarts.
    systemd.user.services.comin-update-notify = {
      description = "Notify when a NixOS update is waiting to be applied";
      partOf = ["graphical-session.target"];
      after = ["graphical-session.target"];
      wantedBy = ["graphical-session.target"];
      serviceConfig = {
        ExecStart = lib.getExe notifier;
        Restart = "always";
        RestartSec = 30;
      };
    };
  };
}
