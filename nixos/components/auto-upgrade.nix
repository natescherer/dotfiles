{
  lib,
  pkgs,
  specialArgs,
  ...
}: let
  # `or null` matches the chezmoi component: removing dotfilesRepo from the
  # flake turns this component into a no-op.
  dotfilesRepo = specialArgs.dotfilesRepo or null;

  notifier = pkgs.writeShellApplication {
    name = "nixos-reboot-notify";
    runtimeInputs = [pkgs.coreutils pkgs.libnotify];
    text = builtins.readFile ./nixos-reboot-notify.sh;
  };
in {
  config = lib.mkIf (dotfilesRepo != null) {
    system.autoUpgrade = {
      enable = true;
      flake = "github:${dotfilesRepo}";
      # The flake's lock file pins nixpkgs, so there are no channels to upgrade.
      upgrade = false;
      # The timer's default persistence catches up on a run missed while the
      # machine was off or asleep.
      dates = "daily";
      operation = "boot";
    };

    # Restarting retries a notification sent before the desktop's notification
    # service is ready.
    systemd.user.services.nixos-reboot-notify = {
      description = "Notify when a reboot is needed to apply a NixOS update";
      partOf = ["graphical-session.target"];
      after = ["graphical-session.target"];
      wantedBy = ["graphical-session.target"];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = lib.getExe notifier;
        Restart = "on-failure";
        RestartSec = 30;
      };
    };

    # Nix replaces the system profile's symlink by renaming over it, so this
    # watches the directory, not the symlink.
    systemd.user.paths.nixos-reboot-notify = {
      description = "Watch for new NixOS generations";
      partOf = ["graphical-session.target"];
      wantedBy = ["graphical-session.target"];
      pathConfig.PathChanged = "/nix/var/nix/profiles";
    };
  };
}
