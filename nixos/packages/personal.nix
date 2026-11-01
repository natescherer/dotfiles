{
  lib,
  pkgs,
  specialArgs,
  ...
}: let
  available = lib.meta.availableOn pkgs.stdenv.hostPlatform;
in {
  imports = [../components/pwas.nix];

  # Packages for personal machines only. Those without a build for the host
  # platform are skipped.
  config = lib.mkIf specialArgs.isPersonal {
    environment.systemPackages = lib.filter available [
      pkgs.discord
      pkgs.obsidian
      pkgs.proton-pass
      pkgs.proton-pass-cli
      pkgs.proton-vpn
      pkgs.protonmail-desktop
      pkgs.slack
      pkgs.ticktick
      pkgs.yubioath-flutter
    ];

    programs.localsend = {
      enable = true;
      openFirewall = true;
    };

    # Yubico Authenticator reaches the key through this.
    services.pcscd.enable = true;

    users.users.${specialArgs.userName}.extraGroups = ["docker"];

    virtualisation.docker = {
      enable = true;
      autoPrune.enable = true;
    };

    xdg.mime.defaultApplications = lib.mkIf (available pkgs.protonmail-desktop) {
      "text/calendar" = "proton-mail.desktop";
      "x-scheme-handler/mailto" = "proton-mail.desktop";
    };
  };
}
