{
  lib,
  pkgs,
  specialArgs,
  ...
}: let
  available = lib.meta.availableOn pkgs.stdenv.hostPlatform;
in {
  # Packages for personal machines only. Those without a build for the host
  # platform are skipped.
  config = lib.mkIf specialArgs.isPersonal {
    environment.systemPackages = lib.filter available [
      pkgs.discord
      pkgs.firefoxpwa
      pkgs.localsend
      pkgs.obsidian
      pkgs.proton-pass
      pkgs.proton-pass-cli
      pkgs.proton-vpn
      pkgs.protonmail-desktop
      pkgs.slack
      pkgs.ticktick
      pkgs.yubioath-flutter
    ];

    programs.firefox.nativeMessagingHosts.packages = [pkgs.firefoxpwa];

    users.users.${specialArgs.userName}.extraGroups = ["docker"];

    virtualisation.docker.enable = true;

    xdg.mime.defaultApplications = lib.mkIf (available pkgs.protonmail-desktop) {
      "text/calendar" = "proton-mail.desktop";
      "x-scheme-handler/mailto" = "proton-mail.desktop";
    };
  };
}
