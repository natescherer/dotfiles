# Windows Setup

## Preflight

1. Sign into Windows (if you made a local account) (and if you want to)
1. Install core drivers/VMware Tools/etc
   - See [docs/drivers](../drivers) for known core driver configs for
     different machines
1. Ensure all Windows Updates are installed
1. Open the Microsoft Store, click `Downloads`, then click
   `Check for updates`, and install all
   - Repeat this step until the store no longer shows any updates

## Automatic Installation

Windows prerequisites can be automatically installed by running the below in
Windows Terminal:

```PowerShell
irm https://raw.githubusercontent.com/natescherer/dotfiles/main/init-windows.ps1 | iex
```

## Manual Installation

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
