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
      # On Wayland, Plasma files these windows under regular Firefox, even though
      # KWin reports the right desktop entry. XWayland keeps each app separate.
      settings.variables.MOZ_ENABLE_WAYLAND = "0";
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
