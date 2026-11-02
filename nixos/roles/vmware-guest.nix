{
  lib,
  pkgs,
  specialArgs,
  ...
}: {
  imports = [../components/vmware-wayland-clipboard.nix];

  # Replaces a generated hardware configuration, covering the virtual disk and
  # USB controllers VMware presents.
  boot.initrd.availableKernelModules = ["nvme" "ahci" "sd_mod" "xhci_pci"];

  # The guest module mounts vmblock with type "fuse", whose mount.fuse helper
  # came from FUSE 2, which nixpkgs removed. vmblock itself uses FUSE 3. Drop
  # this once the module's mount uses type "fuse3".
  environment.systemPackages = [
    (pkgs.runCommand "mount-fuse-compat" {} ''
      mkdir -p $out/bin
      ln -s ${lib.getBin pkgs.fuse3}/bin/mount.fuse3 $out/bin/mount.fuse
    '')
  ];

  home-manager.users.${specialArgs.userName}.programs.plasma = {
    # Numlock off in the guest makes host keyboard software pop up a toggle notice.
    input.keyboard.numlockOnStartup = "on";

    # VMs never turn off the display, lock, or sleep when idle, overriding the desktop role.
    # Hypervisors can pass the host's battery through, so this covers every power state.
    kscreenlocker = {
      autoLock = lib.mkForce false;
      lockOnResume = lib.mkForce false;
    };
    powerdevil = lib.genAttrs ["AC" "battery" "lowBattery"] (_: {
      autoSuspend = {
        action = lib.mkForce "nothing";
        idleTimeout = lib.mkForce null;
      };
      dimDisplay.enable = false;
      turnOffDisplay.idleTimeout = lib.mkForce "never";
    });
  };
  services.displayManager.sddm.autoNumlock = true;

  virtualisation.vmware.guest = {
    enable = true;
    # Defaults to true without services.xserver.enable, which would leave a
    # Wayland desktop with no VMware desktop integration.
    headless = false;
  };
}
