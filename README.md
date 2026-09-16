# README

This repository contains my personal dotfiles for synchronization via [chezmoi](https://www.chezmoi.io).

Where possible, each configuration is set up to work for Linux 🐧, macOS 26+ 🍎,
and Windows 11 🪟. (OS compatibility for each product is indicated with emoji.)

Feel free to use anything here according to your needs!

Currently managed:

- [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/) 🐧 🍎 🪟
  - Config Files
    - [chezmoi/.chezmoidata/env-vars.toml](chezmoi/.chezmoidata/env-vars.toml)
- [Cargo](https://github.com/rust-lang/cargo) 🐧 🍎 🪟
  - Config Files
    - [chezmoi/.chezmoidata/env-vars.toml](chezmoi/.chezmoidata/env-vars.toml)
- [Claude](https://claude.com/) 🐧 🍎 🪟
  - Config Files
    - [chezmoi/dot_config/claude/CLAUDE.md.tmpl](chezmoi/dot_config/claude/CLAUDE.md.tmpl)
    - [chezmoi/dot_config/claude/settings.json](chezmoi/dot_config/claude/settings.json)
- [Clocker](https://abhishekbanthia.com/clocker/) 🍎
  - Notes
    - Configuration is imported via script [chezmoi/.chezmoiscripts/30-macos/run_onchange_defaults-importer.sh.tmpl](chezmoi/.chezmoiscripts/30-macos/run_onchange_defaults-importer.sh.tmpl)
  - Config Files
    - [chezmoi/.scriptdata/macos-defaults/com.abhishek.Clocker.plist](chezmoi/.scriptdata/macos-defaults/com.abhishek.Clocker.plist)
      - Note this is a non-editable binary file, made via `defaults export com.abhishek.Clocker com.abhishek.Clocker.plist`
- [Delta](https://github.com/dandavison/delta) 🐧 🍎 🪟
  - Config Files
    - [chezmoi/dot_config/git/config.tmpl](chezmoi/dot_config/git/config.tmpl)
    - [chezmoi/.chezmoi.yaml.tmpl](chezmoi/.chezmoi.yaml.tmpl)
- [fzf](https://github.com/junegunn/fzf) 🐧 🍎
  - Config Files
    - [chezmoi/dot_config/zsh/dot_zshrc.tmpl](chezmoi/dot_config/zsh/dot_zshrc.tmpl)
- [Ghostty](https://ghostty.org/) 🐧 🍎
  - Notes
    - Notification permissions are pre-granted via a configuration profile, since macOS has no supported way to grant them silently. Installed via script [chezmoi/.chezmoiscripts/30-macos/run_onchange_profiles-importer.sh.tmpl](chezmoi/.chezmoiscripts/30-macos/run_onchange_profiles-importer.sh.tmpl)
  - Config Files
    - [chezmoi/dot_config/ghostty/config.tmpl](chezmoi/dot_config/ghostty/config.tmpl)
    - [chezmoi/.scriptdata/macos-profiles/notifications.mobileconfig](chezmoi/.scriptdata/macos-profiles/notifications.mobileconfig)
- [Git](https://git-scm.com/) 🐧 🍎 🪟
  - Config Files
    - [chezmoi/dot_config/git/config.tmpl](chezmoi/dot_config/git/config.tmpl)
    - [chezmoi/dot_config/git/ignore](chezmoi/dot_config/git/ignore)
  - Folders
    - [chezmoi/git/gh](chezmoi/git/gh) for GitHub repos
    - [chezmoi/git/azdo](chezmoi/git/azdo) for Azure DevOps repos
- [GitHub CLI](https://cli.github.com/) 🐧 🍎 🪟
  - Config Files
    - [chezmoi/dot_config/mise/config.toml](chezmoi/dot_config/mise/config.toml)
    - [chezmoi/dot_config/gh/config.yml](chezmoi/dot_config/gh/config.yml)
- [GnuPG](https://gnupg.org/) 🐧 🍎 🪟
  - Config Files
    - [chezmoi/.chezmoidata/env-vars.toml](chezmoi/.chezmoidata/env-vars.toml)
- [Go](https://https://go.dev/) 🐧 🍎 🪟
  - Config Files
    - [chezmoi/.chezmoidata/env-vars.toml](chezmoi/.chezmoidata/env-vars.toml)
- [k9s](https://github.com/derailed/k9s) 🐧 🍎 🪟
  - Config Files
    - [chezmoi/dot_config/k9s/config.yaml.tmpl](chezmoi/dot_config/k9s/config.yaml.tmpl)
- [kubie](https://github.com/sbstp/kubie) 🐧 🍎
  - Config Files
    - [chezmoi/dot_kube/kubie.yaml](chezmoi/dot_kube/kubie.yaml)
- [macOS](https://www.apple.com/macos/) 🍎
  - Config Files
    - [chezmoi/Library/Application Support/ansible-configuration-chezmoi](<chezmoi/Library/Application Support/ansible-configuration-chezmoi>)
    - [chezmoi/.chezmoiscripts/30-macos/run_onchange_after_ansible-configure.sh.tmpl](chezmoi/.chezmoiscripts/30-macos/run_onchange_after_ansible-configure.sh.tmpl)
- [micro](https://micro-editor.github.io/) 🐧 🍎 🪟
  - Config Files
    - [chezmoi/dot_config/micro/settings.json](chezmoi/dot_config/micro/settings.json)
- [mise](https://mise.jdx.dev) 🐧 🍎 🪟
  - Config Files
    - [chezmoi/dot_config/mise/config.toml](chezmoi/dot_config/mise/config.toml)
- [mpm](https://github.com/kdeldycke/meta-package-manager) 🍎
  - Notes
    - Unified upgrade CLI for every package manager on the machine; it shells out to [topgrade](https://github.com/topgrade-rs/topgrade) automatically for ecosystems it doesn't natively cover, so topgrade needs no separate configuration of its own. A LaunchAgent runs `mpm outdated` (read-only, no privilege escalation) every 12h to cache a plan of pending updates; the pending-update summary (or a check-failed warning) is then surfaced at interactive zsh startup. Run `mpm upgrade --all` manually to apply.
  - Config Files
    - [chezmoi/Library/Application Support/ansible-configuration-chezmoi/group_vars/all/homebrew.a.yml](<chezmoi/Library/Application Support/ansible-configuration-chezmoi/group_vars/all/homebrew.a.yml>)
    - [chezmoi/Library/LaunchAgents/local.mpm-plan.plist](chezmoi/Library/LaunchAgents/local.mpm-plan.plist)
    - [chezmoi/dot_config/zsh/dot_zshrc.tmpl](chezmoi/dot_config/zsh/dot_zshrc.tmpl)
- [npm](https://www.npmjs.com/) 🐧 🍎 🪟
  - Config Files
    - [chezmoi/.chezmoidata/env-vars.toml](chezmoi/.chezmoidata/env-vars.toml)
    - [chezmoi/dot_config/npm/npmrc](chezmoi/dot_config/npm/npmrc)
- [rustup](https://rustup.rs/) 🐧 🍎 🪟
  - Config Files
    - [chezmoi/.chezmoidata/env-vars.toml](chezmoi/.chezmoidata/env-vars.toml)
- Terminal Color Scheme
  - Applied to Ghostty, Windows Terminal, and Visual Studio Code
  - Generated by [Root Loops](https://rootloops.sh/?sugar=6&colors=9&sogginess=0&flavor=1&fruit=10&milk=0)
- [PowerShell](https://github.com/PowerShell/PowerShell) 🐧 🍎 🪟
  - Config Files
    - [chezmoi/Documents/PowerShell/aliases.ps1.tmpl](chezmoi/Documents/PowerShell/aliases.ps1.tmpl)
    - [chezmoi/Documents/PowerShell/env.ps1.tmpl](chezmoi/Documents/PowerShell/env.ps1.tmpl)
    - [chezmoi/Documents/PowerShell/profile.ps1.tmpl](chezmoi/Documents/PowerShell/profile.ps1.tmpl)
- [Proton Pass](https://proton.me/pass) 🐧 🍎 🪟
  - Notes
    - SSH agent vault/key selection (via [Proton Pass CLI](https://protonpass.github.io/pass-cli/)) is set with CLI flags at agent startup rather than a config file
  - Config Files
    - [chezmoi/dot_zshenv.tmpl](chezmoi/dot_zshenv.tmpl)
    - [chezmoi/dot_ssh/config.tmpl](chezmoi/dot_ssh/config.tmpl)
- [Sheldon](https://github.com/rossmacarthur/sheldon) 🐧 🍎
  - Config Files
    - [chezmoi/dot_config/sheldon/plugins.toml](chezmoi/dot_config/sheldon/plugins.toml)
- [Starship](https://starship.rs) 🐧 🍎 🪟
  - Config Files
    - [chezmoi/.chezmoidata/env-vars.toml](chezmoi/.chezmoidata/env-vars.toml)
    - [chezmoi/dot_config/starship/config.toml.tmpl](chezmoi/dot_config/starship/config.toml.tmpl)
- [Stats](https://github.com/exelban/stats) 🍎
  - Notes
    - Configuration is imported via script [chezmoi/.chezmoiscripts/30-macos/run_onchange_defaults-importer.sh.tmpl](chezmoi/.chezmoiscripts/30-macos/run_onchange_defaults-importer.sh.tmpl)
  - Config Files
    - [chezmoi/.scriptdata/macos-defaults/eu.exelban.Stats.plist](chezmoi/.scriptdata/macos-defaults/eu.exelban.Stats.plist)
      - Note this is a non-editable binary file, made via `defaults export eu.exelban.Stats eu.exelban.Stats.plist`
- [Ungoogled Chromium](https://github.com/ungoogled-software/ungoogled-chromium) 🍎
  - Notes
    - Notification permissions are pre-granted via a configuration profile, since macOS has no supported way to grant them silently. Installed via script [chezmoi/.chezmoiscripts/30-macos/run_onchange_profiles-importer.sh.tmpl](chezmoi/.chezmoiscripts/30-macos/run_onchange_profiles-importer.sh.tmpl)
  - Config Files
    - [chezmoi/.scriptdata/macos-profiles/notifications.mobileconfig](chezmoi/.scriptdata/macos-profiles/notifications.mobileconfig)
- [UniGetUI](https://www.marticliment.com/unigetui/) 🪟
  - Notes
    - Uses an unusual model of one-file-per-setting, there are many files under the below directory
  - Config Files
    - [chezmoi/AppData/Local/UniGetUI/Configuration](chezmoi/AppData/Local/UniGetUI/Configuration)
- [VSCodium](https://vscodium.com/) 🐧 🍎 🪟
  - Notes
    - Configured as a single, lightweight general-purpose profile; Visual Studio Code below covers the language-specific IDE profiles, since VSCodium's default Open VSX registry doesn't carry Microsoft's own extensions (Pylance, the Kubernetes tools, etc.)
    - Shares its profile-provisioning data/templates/script with Visual Studio Code below
  - Config Files
    - [chezmoi/.chezmoidata/editors.toml](chezmoi/.chezmoidata/editors.toml)
      - Defines data used to provision profiles (the `[vscodium]` table)
    - [chezmoi/.chezmoitemplates/editors](chezmoi/.chezmoitemplates/editors)
      - Each file in this directory defines the settings for a profile
    - [chezmoi/.chezmoiscripts/90-all/run_onchange_after_editor-profiles.py.tmpl](chezmoi/.chezmoiscripts/90-all/run_onchange_after_editor-profiles.py.tmpl)
      - Performs profile provisioning and updating for both editors
- [Visual Studio Code](https://code.visualstudio.com/) 🐧 🍎 🪟
  - Notes
    - Configured to support the syncing of profiles
    - Shares its profile-provisioning data/templates/script with VSCodium above
  - Config Files
    - [chezmoi/.chezmoidata/editors.toml](chezmoi/.chezmoidata/editors.toml)
      - Defines data used to provision profiles (the `[vscode]` table)
    - [chezmoi/.chezmoitemplates/editors](chezmoi/.chezmoitemplates/editors)
      - Each file in this directory defines the settings for a profile
    - [chezmoi/.chezmoiscripts/90-all/run_onchange_after_editor-profiles.py.tmpl](chezmoi/.chezmoiscripts/90-all/run_onchange_after_editor-profiles.py.tmpl)
      - Performs profile provisioning and updating for both editors
- [VMware Workstation](https://www.vmware.com/products/workstation-pro.html) 🪟
  - Notes
    - VMware stores its session state in the same INI file as its settings, so needed settings are patched in-place via script
  - Config Files
    - [chezmoi/.chezmoidata/windows-ini-patches.toml](chezmoi/.chezmoidata/windows-ini-patches.toml)
- [Windows](https://windows.com) 🪟
  - Config Files
    - [chezmoi/dot_wslconfig](chezmoi/dot_wslconfig)
    - [chezmoi/AppData/Local/winget-configuration-chezmoi](chezmoi/AppData/Local/winget-configuration-chezmoi)
      - Files under this folder are part of a Winget Configuration used to declaratively configure Windows workstatesion <!-- rumdl-disable-line MD013 -->
- [Windows Terminal](https://apps.microsoft.com/detail/9n0dx20hk701) 🪟
  - Config Files
    - [chezmoi/AppData/Local/Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState/settings.json](chezmoi/AppData/Local/Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState/settings.json)
- [Zsh](https://www.zsh.org/) 🐧 🍎
  - Config Files
    - [chezmoi/dot_config/zsh/dot_zsh-aliases.tmpl](chezmoi/dot_config/zsh/dot_zsh-aliases.tmpl)
    - [chezmoi/dot_config/zsh/dot_zshrc.tmpl](chezmoi/dot_config/zsh/dot_zshrc.tmpl)
    - [chezmoi/dot_zshenv.tmpl](chezmoi/dot_zshenv.tmpl)

## Loading this Config

### macOS

#### Preflight

1. Install macOS, logging into Apple Account (unless a VM)
1. Set hostname

#### Automatic Installation

macOS prerequisites can be automatically installed by running the below:

```shell
curl -fS https://raw.githubusercontent.com/natescherer/dotfiles/main/init-macos.sh | bash
```

#### Manual Installation

```shell
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
eval "$(/opt/homebrew/bin/brew shellenv zsh)"
brew install chezmoi
brew install mise
mise use -g python@latest
eval "$(mise env -s zsh)"
chezmoi init --apply natescherer
```

### Linux

Install the following tools however is appropriate for your distro:

- Starship
- Sheldon
- Mise
- Delta
- Zsh (make sure to set as default shell)

Then run the below:

```Shell
mise use -g python@latest
eval "$(mise env -s zsh)"
chezmoi init --apply natescherer
```

### Windows

#### Preflight

1. Sign into Windows (if you made a local account) (and if you want to)
1. Install core drivers/VMware Tools/etc
   - See [docs/drivers] for known core driver configs for different machines
1. Ensure all Windows Updates are installed
1. Open the Microsoft Store, click `Downloads`, then click `Check for updates`, and install all
   - Repeat this step until the store no longer shows any updates

#### Automatic Installation

Windows prerequisites can be automatically installed by running the below in Windows Terminal:

```PowerShell
irm https://raw.githubusercontent.com/natescherer/dotfiles/main/init-windows.ps1 | iex
```

#### Manual Installation

> NOTE: If you are running Windows 11 25H2 and get a certificate error on any of
> the below steps, run the following in Admin Terminal to fix, then reopen a
> non-Admin Terminal and rerun the failed command.
>
> ```PowerShell
> winget settings --enable BypassCertificatePinningForMicrosoftStore
> winget upgrade Microsoft.AppInstaller --accept-source-agreements --accept-package-agreements
> winget settings --disable BypassCertificatePinningForMicrosoftStore
> winget source reset --force
> ```

Install the latest PowerShell using this command SPECIFICALLY, as the default
MSIX install has sandboxing issues, see
<https://github.com/PowerShell/PowerShell/issues/13866>

```PowerShell
winget install --id Microsoft.PowerShell --source winget --installer-type wix
```

Once PowerShell is installed, reopen Windows Terminal and launch a PowerShell
tab instead of Windows PowerShell.

```PowerShell
winget install --id twpayne.chezmoi -e
winget install --id jdx.mise -e
```

Restart the shell, then run the below:

```PowerShell
mise use -g python@latest
mise env -s pwsh | iex
chezmoi init --apply natescherer
```
