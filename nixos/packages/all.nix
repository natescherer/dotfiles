{
  lib,
  pkgs,
  ...
}: {
  # azure-cli needs fabric, and no fabric release supports the invoke 3 in
  # nixpkgs. Remove this once the fix reaches nixos-unstable:
  # https://github.com/NixOS/nixpkgs/pull/576874
  nixpkgs.overlays = [
    (final: prev: {
      pythonPackagesExtensions =
        prev.pythonPackagesExtensions
        ++ [
          (_: pythonPrev: {
            fabric = pythonPrev.fabric.overridePythonAttrs (old: {
              version = "3.2.3-unstable-2026-04-07";
              src = final.fetchFromGitHub {
                owner = "fabric";
                repo = "fabric";
                rev = "cc098ad475dbbe2e10aba72692d83aee58919570";
                hash = "sha256-Z1tGcjdLrzbqcbS6XwapSgDNpyLbBiO21yeqi7XhbpQ=";
              };
              meta = old.meta // {broken = false;};
            });
          })
        ];
    })
  ];

  # Packages for every machine. Those without a build for the host platform are
  # skipped.
  environment.systemPackages = lib.filter (lib.meta.availableOn pkgs.stdenv.hostPlatform) [
    pkgs.awscli2
    # The Python in azure-cli has no pip, so `az extension add` fails. Declare
    # extensions here instead.
    (pkgs.azure-cli.withExtensions [pkgs.azure-cli.extensions.azure-devops])
    pkgs.brave
    pkgs.curl
    pkgs.delta
    pkgs.fzf
    pkgs.gdu
    pkgs.gh
    pkgs.ghostty
    pkgs.git
    pkgs.git-credential-manager
    pkgs.google-cloud-sdk
    pkgs.jq
    pkgs.libnotify
    pkgs.micro
    pkgs.mise
    pkgs.sheldon
    pkgs.starship
    pkgs.vlc
    pkgs.vscode
    pkgs.vscodium
    pkgs.xdg-utils
    pkgs.yq-go
  ];
}
