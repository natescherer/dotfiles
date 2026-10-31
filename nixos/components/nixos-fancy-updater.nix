{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.nixos-fancy-updater;
  # Bump manually for any change to the nixos-fancy-updater CLI/module worth
  # a user being able to tell apart via --version.
  cliVersion = "1.0.0";
  cliUsage = pkgs.writeText "nixos-fancy-updater-usage" ''
    nixos-fancy-updater ${cliVersion}

    Triggers an on-demand run of nixos-fancy-updater.service and streams its
    logs.

    Must be run with sudo, as it calls 'nixos-rebuild switch' under the hood.

    Usage:
      nixos-fancy-updater                Trigger an update check and show its logs
      nixos-fancy-updater -q, --quiet    Trigger an update check without streaming logs
      nixos-fancy-updater -h, --help     Show this help
      nixos-fancy-updater -v, --version  Show version


    Exit codes:
      0  success
      1  the update check itself failed (see the log above)
      2  invalid usage
      3  not run with sudo
  '';
in {
  options.services.nixos-fancy-updater = {
    enable = lib.mkEnableOption "periodic updates from a GitHub-hosted flake";

    githubRepo = lib.mkOption {
      type = lib.types.str;
      example = "owner/repo";
      description = ''
        The `owner/repo` of the GitHub repository containing the flake that
        defines this system.
      '';
    };

    flakeSubfolder = lib.mkOption {
      type = lib.types.str;
      default = "";
      example = "hosts/myhost";
      description = ''
        Subdirectory within the repository containing the flake. Leave
        empty/undefined if the flake lives at the repository root.
      '';
    };

    flakeAttr = lib.mkOption {
      type = lib.types.str;
      default = config.networking.hostName;
      defaultText = lib.literalExpression "config.networking.hostName";
      description = ''
        The `nixosConfigurations` attribute from the flake that defines
        this host.
      '';
    };

    ignorePaths = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "^\\.devcontainer/"
        "^\\.github/"
        "^\\.vscode/"
        "^docs/"
        "\\.editorconfig$"
        "\\.gitattributes$"
        "\\.gitignore$"
        "CHANGELOG\\.md$"
        "CONTRIBUTING\\.md$"
        "LICENSE$"
        "^mise\\.toml$"
        "README\\.md$"
      ];
      example = ["README\\.md$" "\\.gitignore$" "^\\.github/"];
      description = ''
        Regular expressions (Oniguruma syntax, as used by jq's `test()`)
        for files/directories that aren't part of the flake and should
        not trigger a 'nixos-rebuild switch' if they are changed.
        Each is pattern is matched against a file's path relative to the
        repo root (or flakeSubfolder, if set). Make sure to escape characters
        as necessary for Nix strings (see https://nix.dev/manual/nix/2.25/language/string-literals).
        Set to `[ ]` to track every file with no exclusions.
      '';
    };

    githubTokenFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = ''
        If your GitHub repo is private, this should be the path to
        a file containing a GitHub Personal Access Token with read access
        to your repository. Leave undefined for public repos. NOTE: This
        is a secret value and should be protected with sops-nix/agenix/etc.
      '';
    };

    schedule = lib.mkOption {
      type = lib.types.str;
      default = "daily";
      description = "systemd OnCalendar expression for how often to check for updates.";
    };

    appriseUriFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = ''
        Path to a file containing one or more newline-separated Apprise
        notification URLs (see <https://github.com/caronc/apprise#supported-notifications>).
        When set, notifications are sent automatically on update success,
        update failure, and when a reboot is required. If undefined,
        no notifications are sent at all. NOTE: This is a secret
        value and should be managed with sops-nix/agenix/etc.
      '';
    };

    rebootReminderInterval = lib.mkOption {
      type = lib.types.str;
      default = "24h";
      description = ''
        How often to repeat the Apprise "reboot required" notification
        (a systemd time span) until the system is actually rebooted. Only
        has an effect when `appriseUriFile` is set.
      '';
    };

    onSuccess = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = ''
        Additional units to start whenever an update completes, alongside
        the built-in Apprise notification (if `appriseUriFile` is set).
        Fires regardless of whether a reboot is also required -
        `onRebootRequired` fires in addition to this, not instead of it.
      '';
    };

    onFailure = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = ''
        Additional units to start when the update service fails, alongside
        the built-in Apprise notification (if `appriseUriFile` is set).
      '';
    };

    onRebootRequired = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = ''
        Additional units to start when an update was applied but requires
        a reboot to fully take effect (e.g. a kernel/initrd/kernel-modules
        change), alongside the built-in Apprise notification (if
        `appriseUriFile` is set). Fires in addition to `onSuccess`, not
        instead of it.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      (pkgs.writeShellApplication {
        name = "nixos-fancy-updater";
        runtimeInputs = [pkgs.systemd];
        text = ''
          quiet=0
          case "''${1:-}" in
            -h | --help)
              cat ${cliUsage}
              exit 0
              ;;
            -v | --version)
              echo "nixos-fancy-updater ${cliVersion}"
              exit 0
              ;;
            -q | --quiet)
              quiet=1
              ;;
            "") ;;
            *)
              echo "nixos-fancy-updater: unknown option '$1'" >&2
              cat ${cliUsage} >&2
              exit 2
              ;;
          esac

          if [ "$(id -u)" -ne 0 ]; then
            echo "nixos-fancy-updater: must be run with sudo - it starts a system service." >&2
            exit 3
          fi

          # This ensures that failues always exit 1, and still show the logs even if the
          # --quiet flag is supplied
          if ! systemctl start nixos-fancy-updater.service; then
            echo "nixos-fancy-updater: the update check failed; see the log below." >&2
            journalctl _SYSTEMD_INVOCATION_ID="$(systemctl show -p InvocationID --value nixos-fancy-updater.service)" --no-pager
            exit 1
          fi

          if [ "$quiet" -eq 0 ]; then
            journalctl _SYSTEMD_INVOCATION_ID="$(systemctl show -p InvocationID --value nixos-fancy-updater.service)" --no-pager
          fi
        '';
      })
    ];

    systemd.timers."nixos-fancy-updater" = {
      wantedBy = ["timers.target"];
      partOf = ["nixos-fancy-updater.service"];
      timerConfig = {
        OnCalendar = cfg.schedule;
        Persistent = true;
        Unit = "nixos-fancy-updater.service";
      };
    };

    systemd.services."nixos-fancy-updater" = {
      description = "Update NixOS from GitHub-hosted flake ${cfg.githubRepo}";
      # Prevents 'nixos-rebuild switch' from restarting this service in the middle of the switch
      restartIfChanged = false;
      # Cleans this service up properly if it is ever removed from configuration
      unitConfig.X-StopOnRemoval = false;
      # There is deliberately no onSuccess here, because we only want to alert on SOME successes
      onFailure = cfg.onFailure ++ lib.optional (cfg.appriseUriFile != null) "nixos-fancy-updater-apprise-failure.service";
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        StateDirectory = "nixos-fancy-updater";
      };
      path = with pkgs; [
        nixos-rebuild
        nix
        jq
        curl
        systemd
        coreutils
      ];
      script = let
        subfolder = cfg.flakeSubfolder;
        dirParam = lib.optionalString (subfolder != "") "?dir=${subfolder}";
        flakeUri = "github:${cfg.githubRepo}${dirParam}";
        stateDir = "/var/lib/nixos-fancy-updater";
        contentHashFile = "${stateDir}/last-content-hash";
        prefix = lib.optionalString (subfolder != "") "${subfolder}/";
        subfolderNote = lib.optionalString (subfolder != "") " under subfolder '${subfolder}'";
        ignoreRegex = lib.concatMapStringsSep "|" (pat: "(${pat})") cfg.ignorePaths;
        rebootHooks =
          lib.concatMapStringsSep "\n"
          (unit: "systemctl start --no-block ${lib.escapeShellArg unit}")
          (cfg.onRebootRequired ++ lib.optional (cfg.appriseUriFile != null) "nixos-fancy-updater-apprise-reboot-required.timer");
        successHooks =
          lib.concatMapStringsSep "\n"
          (unit: "systemctl start --no-block ${lib.escapeShellArg unit}")
          (cfg.onSuccess ++ lib.optional (cfg.appriseUriFile != null) "nixos-fancy-updater-apprise-success.service");
      in ''
        set -euo pipefail

        githubToken=""
        ${lib.optionalString (cfg.githubTokenFile != null) ''
          githubToken=$(cat ${lib.escapeShellArg cfg.githubTokenFile})
        ''}

        # Using 'nix flake metadata' here because it finds the latest commit
        # to use the same way that 'nixos-rebuild' does. In practice, it's
        # probably just HEAD on your branch.
        latestRev=$(nix flake metadata --refresh --json ${flakeUri} | jq -r '.locked.rev')

        # Here we are calculating a content hash, consisting of the hashed
        # value of the hashes of all the files that aren't ignored by the
        # globs in ignorePaths. This is done in four stages.

        # Stage 1: Get the git tree via the GitHub API.
        repoTree=$(
          curl -sf ''${githubToken:+-H "Authorization: Bearer $githubToken"} \
            "https://api.github.com/repos/${cfg.githubRepo}/git/trees/$latestRev?recursive=1"
        )

        # Stage 2: Filters $repoTree down to just the files that start with
        # $prefix (derived from option 'subfolder'), as well as splitting
        # $prefix off the start of their paths. Does no filtering or
        # transformation if option 'subfolder' is not provided.
        prefixedBlobs=$(
          echo "$repoTree" \
            | jq -c --arg prefix ${lib.escapeShellArg prefix} '
                .tree[]
                | select(.type == "blob")
                | select(.path | startswith($prefix))
                | {path: .path[($prefix | length):], sha: .sha}
              '
        )

        # Stage 3: Filters $prefixedBlobs down to contain just the files
        # that don't match $ignoreRegex (derived from option 'ignorePaths').
        # Returns a list of the SHAs of all files, erroring out if there are
        # no files left after filtering.
        trackedBlobShas=$(
          echo "$prefixedBlobs" \
            | jq -r --arg ignoreRe ${lib.escapeShellArg ignoreRegex} '
                select(($ignoreRe == "") or ((.path | test($ignoreRe)) | not))
                | .sha
              '
        )
        if [ -z "$trackedBlobShas" ]; then
          echo "No trackable files found${subfolderNote} (after ignorePaths) at rev $latestRev" >&2
          exit 1
        fi

        # Stage 4: Sort the list of SHAs alphabetically, then calculate the
        # checksum of that list. This is our final content hash that will
        # be used to tell whether or not nixos-rebuild needs to be ran.
        contentHash=$(echo "$trackedBlobShas" | sort | sha256sum | cut -d' ' -f1)

        # Loads the content hash from last 'nixos-rebuild switch' from
        # the file where it is saved
        lastContentHash=""
        if [ -f ${contentHashFile} ]; then
          lastContentHash=$(cat ${contentHashFile})
        fi

        # Exits here if the hashes match, that means there were no relevant
        # changes to the flake that would require a nixos-rebuild
        if [ "$contentHash" = "$lastContentHash" ]; then
          echo "Flake contents unchanged ($contentHash); skipping rebuild."
          exit 0
        fi

        # Perform the actual update now that we've determined it's needed
        nixos-rebuild switch --flake ${flakeUri}#${cfg.flakeAttr} --refresh

        # Save the newly-calculated contentHash to a file for later runs to
        # compare against
        echo "$contentHash" > ${contentHashFile}

        # The switch above already succeeded, regardless of whether a
        # reboot also turns out to be required - so successHooks always
        # fires; rebootHooks fires additionally on top of it, not instead.
        ${successHooks}

        # A kernel/initrd/kernel-modules change only takes effect after a
        # reboot; /run/booted-system still reflects the pre-switch generation
        # until then, so a mismatch here means a reboot is pending.
        bootedSystem="$(readlink /run/booted-system/{initrd,kernel,kernel-modules})"
        currentSystem="$(readlink /run/current-system/{initrd,kernel,kernel-modules})"
        if [ "$bootedSystem" != "$currentSystem" ]; then
          echo "Kernel, initrd, or kernel modules changed; reboot required."
          ${rebootHooks}
        fi
      '';
    };

    systemd.services."nixos-fancy-updater-apprise-success" = lib.mkIf (cfg.appriseUriFile != null) {
      description = "Notify via Apprise that nixos-fancy-updater succeeded";
      serviceConfig.Type = "oneshot";
      path = [pkgs.apprise pkgs.nvd pkgs.diffutils pkgs.nix];
      script = ''
        packageDiff=$(nvd diff /run/booted-system /run/current-system 2>&1 \
          | sed -E '/^(<<<|>>>)/d; /^Closure size:/d' \
          | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')
        etcDiff=$(diff -rq /run/booted-system/etc /run/current-system/etc 2>/dev/null | sed -E 's#^Files /run/booted-system(/etc/.*) and /run/current-system/etc/.* differ$#\1#')
        if [ -z "$etcDiff" ]; then
          etcDiff="(no /etc changes)"
        fi
        apprise -i html -t "NixOS update succeeded" -b "<b>${config.networking.hostName}</b> successfully updated to a new generation.<br><u>Package changes:</u><br><br><pre>$packageDiff</pre><br><u>Config file changes:</u><br><br><pre>$etcDiff</pre>" $(cat ${lib.escapeShellArg cfg.appriseUriFile})
      '';
    };

    systemd.services."nixos-fancy-updater-apprise-failure" = lib.mkIf (cfg.appriseUriFile != null) {
      description = "Notify via Apprise that nixos-fancy-updater failed";
      serviceConfig.Type = "oneshot";
      path = [pkgs.apprise];
      script = ''
        journal=$(journalctl -u nixos-fancy-updater.service -n 20 -o cat | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')
        apprise -i html -t "NixOS update failed" -b "<b>nixos-fancy-updater</b> failed on <b>${config.networking.hostName}</b><br><u>Journal tail:</u><br><br><pre>$journal</pre>" $(cat ${lib.escapeShellArg cfg.appriseUriFile})
      '';
    };

    # This service only starts on demand (and repeats via its timer)
    # by nixos-fancy-updater when a switch leaves a reboot pending, and stops
    # on the next reboot
    systemd.services."nixos-fancy-updater-apprise-reboot-required" = lib.mkIf (cfg.appriseUriFile != null) {
      description = "Notify via Apprise that a reboot is required";
      after = ["network-online.target"];
      wants = ["network-online.target"];
      serviceConfig.Type = "oneshot";
      path = [pkgs.apprise pkgs.nvd pkgs.nix];
      script = ''
        reason=""
        for component in initrd kernel kernel-modules; do
          old="$(readlink "/run/booted-system/$component")"
          new="$(readlink "/run/current-system/$component")"
          if [ "$old" != "$new" ]; then
            componentDiff=$(nvd diff "$old" "$new" 2>&1 \
              | sed -E '/^(<<<|>>>)/d; /^Closure size:/d' \
              | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')
            reason="$reason<br><b>$component</b><br><pre>$componentDiff</pre>"
          fi
        done
        apprise -i html -t "Reboot required" -b "<b>${config.networking.hostName}</b> has pending updates that require a reboot to take effect.<br><u>Why:</u>$reason" $(cat ${lib.escapeShellArg cfg.appriseUriFile})
      '';
    };

    systemd.timers."nixos-fancy-updater-apprise-reboot-required" = lib.mkIf (cfg.appriseUriFile != null) {
      timerConfig = {
        OnActiveSec = "0s";
        OnUnitActiveSec = cfg.rebootReminderInterval;
        Unit = "nixos-fancy-updater-apprise-reboot-required.service";
      };
    };
  };
}
