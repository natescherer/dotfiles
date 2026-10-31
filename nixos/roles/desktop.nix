{
  inputs,
  lib,
  pkgs,
  specialArgs,
  ...
}: let
  # In panel order. Pins are personal-only, as on the other OSes. An entry's
  # package, when set, drops the pin on platforms that package doesn't support.
  pins = [
    {desktop = "org.kde.dolphin";}
    {desktop = "systemsettings";}
    {desktop = "org.kde.plasma-systemmonitor";}
    {desktop = "com.mitchellh.ghostty";}
    {
      desktop = "proton-mail";
      package = pkgs.protonmail-desktop;
    }
    {
      desktop = "discord";
      package = pkgs.discord;
    }
    {desktop = "firefox";}
    {desktop = "brave-browser";}
    {desktop = "ticktick";}
    {desktop = "md.obsidian.Obsidian";}
    {desktop = "codium";}
    {desktop = "code";}
    {
      desktop = "FFPWA-${import ../components/pwa-ulid.nix {inherit lib;} "https://www.youtube.com"}";
      package = pkgs.firefoxpwa;
    }
  ];
  launchers =
    map (pin: "applications:${pin.desktop}.desktop")
    (lib.filter
      (pin: pin ? package -> lib.meta.availableOn pkgs.stdenv.hostPlatform pin.package)
      pins);
in {
  imports = [
    ../packages/all.nix
    ../packages/personal.nix
  ];

  hardware.graphics.enable = true;

  # Lets prebuilt, dynamically linked binaries (mise's python and uv) run.
  programs.nix-ld.enable = true;
  # mise compiles from source on NixOS by default, without checking for nix-ld.
  environment.sessionVariables.MISE_ALL_COMPILE = "false";
  programs.firefox.enable = true;

  nixpkgs.config.allowUnfree = true;

  security.rtkit.enable = true;

  services.desktopManager.plasma6.enable = true;
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
  };

  # Keeps the machine awake with the lid closed on power, so it stays reachable.
  services.logind.settings.Login.HandleLidSwitchExternalPower = "ignore";

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "hm-backup";
    sharedModules = [inputs.plasma-manager.homeModules.plasma-manager];
    users.${specialArgs.userName} = {
      home.stateVersion = "26.05";

      programs.plasma = {
        enable = true;

        workspace = {
          lookAndFeel = "org.kde.breezedark.desktop";
          wallpaper = ../../chezmoi/Pictures/wallpaper-chezmoi/ubuntu-default.jpg;
        };

        panels = [
          {
            location = "bottom";
            widgets = [
              "org.kde.plasma.kickoff"
              (
                if specialArgs.isPersonal
                then {iconTasks.launchers = launchers;}
                else "org.kde.plasma.icontasks"
              )
              "org.kde.plasma.marginsseparator"
              "org.kde.plasma.systemtray"
              "org.kde.plasma.digitalclock"
            ];
          }
        ];

        powerdevil.AC.autoSuspend.action = "nothing";

        configFile = {
          kdeglobals."KFileDialog Settings" = {
            "Show hidden files" = true;
            "Sort directories first" = true;
          };
        };

        # ViewMode 1 is Dolphin's details (list) view.
        dataFile."dolphin/view_properties/global/.directory" = {
          Dolphin.ViewMode = 1;
          Settings.HiddenFilesShown = true;
        };
      };
    };
  };
}
