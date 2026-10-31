{
  lib,
  pkgs,
  ...
}: {
  # Packages for every machine. Those without a build for the host platform are
  # skipped.
  environment.systemPackages = lib.filter (lib.meta.availableOn pkgs.stdenv.hostPlatform) [
    pkgs.brave
    pkgs.curl
    pkgs.delta
    pkgs.fzf
    pkgs.ghostty
    pkgs.git
    pkgs.git-credential-manager
    pkgs.jq
    pkgs.libnotify
    pkgs.micro
    pkgs.mise
    pkgs.sheldon
    pkgs.vlc
    pkgs.vscode
    pkgs.vscodium
    pkgs.xdg-utils
    pkgs.yq-go
  ];
}
