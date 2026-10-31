{
  pkgs,
  lib,
  specialArgs,
  ...
}: let
  # `or null` (rather than a bare attribute access) means removing the
  # dotfilesRepo line from the flake entirely - not just setting it to null -
  # still evaluates cleanly instead of hitting a missing attribute error.
  dotfilesRepo = specialArgs.dotfilesRepo or null;
  home = "/home/${specialArgs.userName}";
  chezmoiSourceDir = "${home}/.local/share/chezmoi";

  # `chezmoi init` can run arbitrary prompts from a .chezmoi.toml.tmpl in the
  # target repo, which would hang forever with no TTY attached to a systemd
  # service. So init is never run automatically; this is nagged at interactive
  # login (see programs.zsh.interactiveShellInit below) until the user has run
  # it themselves. Evaluated fresh on every login rather than baked into a
  # static /etc/motd, so it disappears the moment init actually finishes
  # instead of lagging until the next switch.
  nagMessage = pkgs.writeText "chezmoi-nag" ''
    chezmoi has not been initialized for ${specialArgs.userName} yet. Run this once, interactively, to set it up:

      chezmoi init --apply ${dotfilesRepo}
  '';
in {
  # Wrapping the whole module in config = mkIf here (rather than gating each
  # option individually) means this component is a true no-op - no package,
  # no shell hook - whenever dotfilesRepo isn't set.
  config = lib.mkIf (dotfilesRepo != null) {
    environment.systemPackages = [pkgs.chezmoi];

    programs.zsh.interactiveShellInit = ''
      if [ "$(id -un)" = ${lib.escapeShellArg specialArgs.userName} ] && [ ! -d ${lib.escapeShellArg chezmoiSourceDir} ]; then
        cat ${nagMessage}
      fi
    '';
  };
}
