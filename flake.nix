{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  inputs.disko.url = "github:nix-community/disko";
  inputs.disko.inputs.nixpkgs.follows = "nixpkgs";
  inputs.sops-nix.url = "github:Mic92/sops-nix";
  inputs.sops-nix.inputs.nixpkgs.follows = "nixpkgs";
  inputs.home-manager.url = "github:nix-community/home-manager";
  inputs.home-manager.inputs.nixpkgs.follows = "nixpkgs";
  inputs.plasma-manager.url = "github:nix-community/plasma-manager";
  inputs.plasma-manager.inputs.nixpkgs.follows = "nixpkgs";
  inputs.plasma-manager.inputs.home-manager.follows = "home-manager";

  outputs = {
    nixpkgs,
    disko,
    home-manager,
    ...
  } @ inputs: let
    mkHost = {
      hostName,
      system,
      modules,
      isPersonal ? true,
      diskoDevice ? "/dev/nvme0n1",
    }:
      nixpkgs.lib.nixosSystem {
        specialArgs = {
          inherit inputs hostName isPersonal diskoDevice;
          sshPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHlSrZZgdT/pS9UumSUX3xzQXiNgWyTMi7nFk5vhoEdm dotfiles-nixos-2610";
          userName = "nate";
          diskoConfig = "basic.nix";
          timeZone = "America/New_York";
          dotfilesRepo = "natescherer/dotfiles";
        };
        inherit system;
        modules =
          [
            disko.nixosModules.disko
            home-manager.nixosModules.home-manager
            ./nixos/configuration.nix
            ./nixos/roles/desktop.nix
          ]
          ++ modules;
      };
  in {
    nixosConfigurations.nixos-vmw-wk = mkHost {
      hostName = "nixos-vmw-wk";
      system = "x86_64-linux";
      modules = [./nixos/roles/vmware-guest.nix];
    };
    nixosConfigurations.nixos-vmw-fus = mkHost {
      hostName = "nixos-vmw-fus";
      system = "aarch64-linux";
      modules = [./nixos/roles/vmware-guest.nix];
    };
    # What init-devcontainer.sh installs into a devcontainer's Nix profile:
    # chezmoi, plus the tools the dotfiles' git and zsh config expect. mise
    # comes from the project's own devcontainer, since its tools need it.
    packages =
      nixpkgs.lib.genAttrs ["x86_64-linux" "aarch64-linux"]
      (system: let
        pkgs = nixpkgs.legacyPackages.${system};
      in {
        devcontainer = pkgs.buildEnv {
          name = "dotfiles-devcontainer";
          paths = [
            pkgs.chezmoi
            pkgs.delta
            pkgs.fzf
            pkgs.sheldon
            pkgs.starship
          ];
        };
      });
  };
}
