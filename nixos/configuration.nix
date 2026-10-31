{
  config,
  inputs,
  options,
  pkgs,
  specialArgs,
  lib,
  ...
}: {
  imports = [
    inputs.sops-nix.nixosModules.sops
    ./disko/${specialArgs.diskoConfig}
    ./components/console.nix
    ./components/nixos-fancy-updater.nix
    ./components/chezmoi.nix
  ];

  boot.loader = {
    systemd-boot = {
      enable = true;
      configurationLimit = lib.mkDefault 10; # This limits the number of bootloaders kept from auto-updates
    };
    efi.canTouchEfiVariables = true;
  };
  boot.tmp.useTmpfs = true; # Stores /tmp in RAM to limit wear on storage

  networking.hostName = specialArgs.hostName;

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };
  nix.settings.auto-optimise-store = true;
  nix.settings.experimental-features = ["nix-command" "flakes"];

  networking.networkmanager.enable = true;

  programs.starship.enable = true;
  programs.zsh.enable = true;

  services.fail2ban = {
    enable = true;
    maxretry = 5;
  };

  services.journald.extraConfig = ''
    SystemMaxUse=200M
    RuntimeMaxUse=50M
  ''; # These settings optimize journal size to stay in RAM

  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
    settings.KbdInteractiveAuthentication = false;
  };

  sops.age.sshKeyPaths = ["/etc/ssh/ssh_host_ed25519_key"];
  # sops-install-secrets converts sops.age.sshKeyPaths keys to X25519
  # identities and can only unwrap X25519-type stanzas on its own. The secrets
  # file is encrypted using the sops CLI's native ssh-ed25519 recipient support
  # instead, which needs this native-ssh-identity path too.
  # See https://github.com/Mic92/sops-nix/issues/824.
  sops.environment.SOPS_AGE_SSH_PRIVATE_KEY_FILE = "/etc/ssh/ssh_host_ed25519_key";
  sops.defaultSopsFile = ./secrets.yaml;
  sops.defaultSopsFormat = "yaml";
  sops.secrets.apprise_uri = {};
  sops.secrets."${specialArgs.userName}@${specialArgs.hostName}_passwordhash".neededForUsers = true;

  services.nixos-fancy-updater = {
    enable = true;
    githubRepo = specialArgs.githubRepo;
    flakeSubfolder = specialArgs.flakeSubfolder;
    schedule = specialArgs.updateSchedule;
    appriseUriFile = config.sops.secrets.apprise_uri.path;
    # The flake shares its repo with dotfiles, whose commits shouldn't trigger
    # a rebuild.
    ignorePaths =
      options.services.nixos-fancy-updater.ignorePaths.default
      ++ [
        "^chezmoi/"
        "^helpers/"
        "^init-"
        "AGENTS\\.md$"
        "TODO\\.md$"
        "renovate\\.json$"
      ];
  };

  system.autoUpgrade.enable = false;
  system.stateVersion = "26.05";

  zramSwap.enable = true;

  time.timeZone = specialArgs.timeZone;

  users.defaultUserShell = pkgs.zsh;

  # zsh runs its own first-run "zsh-newuser-install" wizard whenever a user
  # has none of ~/.zshenv, ~/.zprofile, ~/.zshrc, or ~/.zlogin - a check
  # baked into zsh itself (Src/Modules/newuser.c), so there's no module option
  # for it. Create an empty ~/.zshenv for each user until chezmoi replaces it
  # (only if missing, so this never overwrites an existing file).
  system.activationScripts.zshenvDefaults = ''
    for spec in "root:/root" "${specialArgs.userName}:/home/${specialArgs.userName}"; do
      user=''${spec%%:*}
      home=''${spec#*:}
      if [ -d "$home" ] && [ ! -e "$home/.zshenv" ]; then
        # -g "$user" assumed a same-named group, which isNormalUser doesn't
        # create by default (it uses the shared "users" group instead) -
        # look up whatever the user's real primary group actually is.
        install -o "$user" -g "$(id -gn "$user")" -m 0644 /dev/null "$home/.zshenv"
      fi
    done
  '';

  users.users.${specialArgs.userName} = {
    isNormalUser = true;
    createHome = true;
    extraGroups = [
      "wheel"
      "networkmanager"
    ];
    hashedPasswordFile =
      config.sops.secrets."${specialArgs.userName}@${specialArgs.hostName}_passwordhash".path;
    openssh.authorizedKeys.keys = [
      specialArgs.sshPublicKey
    ];
  };
}
