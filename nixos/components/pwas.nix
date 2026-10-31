{
  lib,
  pkgs,
  specialArgs,
  ...
}: let
  ulid = import ./pwa-ulid.nix {inherit lib;};

  entries =
    lib.filter (entry: !lib.elem "linux" (entry.ignore_on or []))
    (lib.importTOML ../../chezmoi/.chezmoidata/pwas.toml).pwas.entries;

  # "Prime Video" becomes primevideo, which names the icon file.
  slug = name: lib.toLower (builtins.replaceStrings [" " "+"] ["" ""] name);
in {
  config = lib.mkIf (specialArgs.isPersonal && lib.meta.availableOn pkgs.stdenv.hostPlatform pkgs.firefoxpwa) {
    home-manager.users.${specialArgs.userName}.programs.firefoxpwa = {
      enable = true;
      profiles.${ulid "pwas"}.sites = lib.listToAttrs (map (entry:
        lib.nameValuePair (ulid entry.url) {
          inherit (entry) name url;
          desktopEntry = {
            icon = "${./pwa-icons}/${slug entry.name}.png";
            categories = ["AudioVideo" "Video"];
          };
        })
      entries);
    };
  };
}
