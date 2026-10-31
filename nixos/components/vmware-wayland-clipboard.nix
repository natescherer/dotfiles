{
  lib,
  pkgs,
  ...
}: let
  bridge = pkgs.writeShellApplication {
    name = "vmware-wayland-clipboard";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gawk
      pkgs.gnugrep
      pkgs.util-linux
      pkgs.wl-clipboard
      pkgs.xsel
    ];
    text = builtins.readFile ./vmware-wayland-clipboard.sh;
  };
in {
  # vmware-user only sees the X11 clipboard, and KWin only passes the Wayland
  # clipboard to X11 while an X11 window has focus. This copies text across so
  # copying from native Wayland apps reaches the host.
  systemd.user.services.vmware-wayland-clipboard = {
    description = "Bridge the Wayland text clipboard to VMware through XWayland";
    partOf = ["graphical-session.target"];
    after = ["graphical-session.target"];
    wantedBy = ["graphical-session.target"];
    serviceConfig = {
      ExecStart = "${lib.getExe' pkgs.wl-clipboard "wl-paste"} --type text --watch ${lib.getExe bridge}";
      Restart = "on-failure";
      RestartSec = 2;
    };
  };
}
