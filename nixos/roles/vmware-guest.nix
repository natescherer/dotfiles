{
  lib,
  pkgs,
  ...
}: {
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

  virtualisation.vmware.guest = {
    enable = true;
    # Defaults to true without services.xserver.enable, which would leave a
    # Wayland desktop with no VMware desktop integration.
    headless = false;
  };
}
