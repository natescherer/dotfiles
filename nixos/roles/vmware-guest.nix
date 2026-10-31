{...}: {
  # Replaces a generated hardware configuration, covering the virtual disk and
  # USB controllers VMware presents.
  boot.initrd.availableKernelModules = ["nvme" "ahci" "sd_mod" "xhci_pci"];

  virtualisation.vmware.guest = {
    enable = true;
    # Defaults to true without services.xserver.enable, which would leave a
    # Wayland desktop with no VMware desktop integration.
    headless = false;
  };
}
